package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2"
	"github.com/mulutu/security-manager/internal/proto"
	"github.com/nats-io/nats.go"
	"google.golang.org/grpc"
	gproto "google.golang.org/protobuf/proto" // alias to avoid name clash
)

const subjFmt = "logs.%s.%s" // org_id, host_id

// ─── gRPC server implementation ──────────────────────────────────────────

type ingestServer struct {
	proto.UnimplementedAgentIngestServer
	js nats.JetStreamContext
}

func (s *ingestServer) StreamEvents(stream proto.AgentIngest_StreamEventsServer) error {
	for {
		ev, err := stream.Recv()
		if err != nil {
			return err // client closed stream
		}
		subj := fmt.Sprintf(subjFmt, ev.OrgId, ev.HostId)

		data, _ := gproto.Marshal(ev) // use the aliased helper
		if _, err := s.js.PublishAsync(subj, data); err != nil {
			log.Printf("nats publish error: %v", err)
		}
	}
}

// ─── main ────────────────────────────────────────────────────────────────

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// 1️⃣  NATS JetStream
	nc, err := nats.Connect(getEnv("NATS_URL", "nats://localhost:4222"))
	if err != nil {
		log.Fatalf("nats: %v", err)
	}
	js, _ := nc.JetStream()
	js.AddStream(&nats.StreamConfig{Name: "LOGS", Subjects: []string{"logs.>"}})

	// 2️⃣  ClickHouse
	ch, err := clickhouse.Open(&clickhouse.Options{
		Addr: []string{getEnv("CLICKHOUSE_ADDR", "localhost:9000")},
	})
	if err != nil {
		log.Fatalf("clickhouse: %v", err)
	}

	// 3️⃣  gRPC server
	lis, err := net.Listen("tcp", ":9002")
	if err != nil {
		log.Fatalf("listen: %v", err)
	}
	grpcSrv := grpc.NewServer()
	proto.RegisterAgentIngestServer(grpcSrv, &ingestServer{js: js})

	go func() {
		log.Println("ingest gRPC listening on :9002")
		if err := grpcSrv.Serve(lis); err != nil {
			log.Fatalf("serve: %v", err)
		}
	}()

	// 4️⃣  JS → ClickHouse sink (runs until ctx cancelled)
	go clickhouseSink(ctx, js, ch)

	<-ctx.Done()
	log.Println("shutdown…")
	grpcSrv.GracefulStop()
	nc.Drain()
}

// ─── helper routines ─────────────────────────────────────────────────────

func clickhouseSink(ctx context.Context, js nats.JetStreamContext, ch clickhouse.Conn) {
	sub, _ := js.PullSubscribe("logs.>", "ingest-sink", nats.PullMaxWaiting(128))

	for {
		select {
		case <-ctx.Done():
			return
		default:
			msgs, _ := sub.Fetch(256, nats.MaxWait(500*time.Millisecond))
			if len(msgs) == 0 {
				continue
			}

			batch, _ := ch.PrepareBatch(ctx, `INSERT INTO events
				(org_id, host_id, ts, stream, message, labels)`)

			for _, m := range msgs {
				ev := new(proto.LogEvent)
				if err := gproto.Unmarshal(m.Data, ev); err != nil { // use aliased helper
					m.Nak()
					continue
				}
				batch.Append(
					ev.OrgId, ev.HostId,
					time.Unix(0, ev.TsUnixNs),
					ev.Stream, ev.Message, ev.Labels,
				)
				m.Ack()
			}
			batch.Send()
		}
	}
}

func getEnv(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}
