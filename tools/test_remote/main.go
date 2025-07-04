package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	pb "github.com/mulutu/security-manager/internal/proto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func main() {
	var (
		ingestURL = flag.String("ingest", getEnvOrDefault("SM_INGEST_URL", "178.79.139.38:9002"), "gRPC ingest host:port")
		orgID     = flag.String("org", getEnvOrDefault("SM_ORG_ID", "demo"), "organization ID")
		token     = flag.String("token", getEnvOrDefault("SM_TOKEN", "sm_tok_demo123"), "authentication token")
	)
	flag.Parse()

	fmt.Printf("🔗 Testing connection to remote ingest service\n")
	fmt.Printf("   Endpoint: %s\n", *ingestURL)
	fmt.Printf("   Org ID: %s\n", *orgID)
	fmt.Printf("   Token: %s\n\n", *token)

	// Connect to ingest service
	fmt.Printf("📡 Connecting to %s...\n", *ingestURL)
	conn, err := grpc.Dial(*ingestURL, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("❌ Connection failed: %v", err)
	}
	defer conn.Close()

	client := pb.NewAgentIngestClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Test authentication
	fmt.Printf("🔐 Testing authentication...\n")
	authResp, err := client.Authenticate(ctx, &pb.AuthRequest{
		OrgId:        *orgID,
		Token:        *token,
		AgentVersion: "1.0.0-test",
	})
	if err != nil {
		log.Fatalf("❌ Authentication failed: %v", err)
	}

	if !authResp.Authenticated {
		log.Fatalf("❌ Authentication rejected: %s", authResp.ErrorMessage)
	}

	fmt.Printf("✅ Authentication successful!\n")
	fmt.Printf("   Heartbeat interval: %d seconds\n", authResp.HeartbeatIntervalSeconds)

	// Test streaming connection
	fmt.Printf("🔄 Testing streaming connection...\n")
	stream, err := client.StreamEvents(ctx)
	if err != nil {
		log.Fatalf("❌ Stream creation failed: %v", err)
	}

	// Send a test event
	testEvent := &pb.LogEvent{
		OrgId:    *orgID,
		HostId:   "test-host",
		TsUnixNs: time.Now().UnixNano(),
		Stream:   "test",
		Message:  "Test message from remote connectivity test",
		Labels:   map[string]string{"test": "true", "source": "remote-test"},
	}

	err = stream.Send(testEvent)
	if err != nil {
		log.Fatalf("❌ Failed to send test event: %v", err)
	}

	fmt.Printf("✅ Test event sent successfully!\n")

	// Close the stream
	err = stream.CloseSend()
	if err != nil {
		log.Printf("⚠️  Warning: Failed to close stream: %v", err)
	}

	fmt.Printf("\n🎉 All tests passed! Remote ingest service is working correctly.\n")
	fmt.Printf("\n📊 Summary:\n")
	fmt.Printf("   ✅ Network connectivity\n")
	fmt.Printf("   ✅ gRPC service responding\n")
	fmt.Printf("   ✅ Authentication working\n")
	fmt.Printf("   ✅ Event streaming functional\n")
	fmt.Printf("\n🚀 You can now deploy agents to connect to this service.\n")
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
