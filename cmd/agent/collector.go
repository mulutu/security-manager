package main

import (
	"bufio"
	"context"
	"log"
	"os"
	"time"

	pb "github.com/mulutu/security-manager/internal/proto"
)

// runCollector = heartbeat + optional file-tail
func runCollector(
	ctx context.Context,
	stream pb.AgentIngest_StreamEventsClient,
	org, host, file string,
	heartbeatIntervalSeconds int64,
) error {

	// Use server-provided heartbeat interval, fallback to 30s
	interval := time.Duration(heartbeatIntervalSeconds) * time.Second
	if interval <= 0 {
		interval = 30 * time.Second
	}

	/* heartbeat */
	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case now := <-ticker.C:
				err := stream.Send(&pb.LogEvent{
					OrgId:    org,
					HostId:   host,
					TsUnixNs: now.UnixNano(),
					Stream:   "heartbeat",
					Message:  "agent alive",
				})
				if err != nil {
					log.Printf("heartbeat send error: %v", err)
					return
				}
			}
		}
	}()

	/* optional file tail */
	if file != "" {
		go tailFile(ctx, stream, org, host, file)
	}

	<-ctx.Done()
	return ctx.Err()
}

/* tailFile sends each new line as stream="file" */
func tailFile(ctx context.Context, s pb.AgentIngest_StreamEventsClient, org, host, path string) {
	f, err := os.Open(path)
	if err != nil {
		log.Printf("tail open %s: %v", path, err)
		return
	}
	defer f.Close()

	f.Seek(0, os.SEEK_END) // jump to end
	r := bufio.NewReader(f)

	log.Printf("📁 Tailing file: %s", path)

	for {
		select {
		case <-ctx.Done():
			return
		default:
			line, err := r.ReadString('\n')
			if err != nil {
				time.Sleep(500 * time.Millisecond)
				continue
			}

			err = s.Send(&pb.LogEvent{
				OrgId:    org,
				HostId:   host,
				TsUnixNs: time.Now().UnixNano(),
				Stream:   "file",
				Message:  line,
			})
			if err != nil {
				log.Printf("file tail send error: %v", err)
				return
			}
		}
	}
}
