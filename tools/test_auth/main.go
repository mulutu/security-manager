package main

import (
	"context"
	"log"
	"time"

	pb "github.com/mulutu/security-manager/internal/proto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func main() {
	// Connect to ingest service
	conn, err := grpc.Dial("localhost:9002", grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("dial failed: %v", err)
	}
	defer conn.Close()

	client := pb.NewAgentIngestClient(conn)

	// Test 1: Valid authentication
	log.Println("🔐 Testing valid authentication...")
	authResp, err := client.Authenticate(context.Background(), &pb.AuthRequest{
		OrgId:        "demo",
		Token:        "sm_tok_demo123",
		AgentVersion: "1.0.0-test",
	})
	if err != nil {
		log.Fatalf("auth request failed: %v", err)
	}

	if authResp.Authenticated {
		log.Printf("✅ Authentication successful! Heartbeat interval: %ds", authResp.HeartbeatIntervalSeconds)
	} else {
		log.Printf("❌ Authentication failed: %s", authResp.ErrorMessage)
	}

	// Test 2: Invalid token
	log.Println("\n🔐 Testing invalid token...")
	authResp2, err := client.Authenticate(context.Background(), &pb.AuthRequest{
		OrgId:        "demo",
		Token:        "invalid_token",
		AgentVersion: "1.0.0-test",
	})
	if err != nil {
		log.Fatalf("auth request failed: %v", err)
	}

	if !authResp2.Authenticated {
		log.Printf("✅ Invalid token correctly rejected: %s", authResp2.ErrorMessage)
	} else {
		log.Printf("❌ Invalid token was accepted (security issue!)")
	}

	// Test 3: Send a test event (if authenticated)
	if authResp.Authenticated {
		log.Println("\n📤 Testing event streaming...")
		stream, err := client.StreamEvents(context.Background())
		if err != nil {
			log.Fatalf("stream failed: %v", err)
		}

		err = stream.Send(&pb.LogEvent{
			OrgId:    "demo",
			HostId:   "test-host",
			TsUnixNs: time.Now().UnixNano(),
			Stream:   "test",
			Message:  "Authentication test successful!",
		})
		if err != nil {
			log.Printf("❌ Send failed: %v", err)
		} else {
			log.Printf("✅ Test event sent successfully")
		}

		stream.CloseSend()
	}

	log.Println("\n🎉 Authentication tests completed!")
}
