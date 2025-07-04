package main

import (
	"context"
	"time"

	pb "github.com/mulutu/security-manager/internal/proto"
	"google.golang.org/grpc"
)

func main() {
	// gRPC endpoint from Docker Compose
	conn, err := grpc.Dial("178.79.139.38:9002", grpc.WithInsecure())
	if err != nil {
		panic(err)
	}
	defer conn.Close()

	stream, _ := pb.NewAgentIngestClient(conn).StreamEvents(context.Background())

	_ = stream.Send(&pb.LogEvent{
		OrgId:    "demo",
		HostId:   "vm1",
		TsUnixNs: time.Now().UnixNano(),
		Stream:   "syslog",
		Message:  "hello from test",
	})
}
