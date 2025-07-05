package main

import (
	"context"
	"crypto/tls"
	"log"
	"net"
	"os"
	"os/signal"
	"regexp"
	"syscall"
	"time"

	"github.com/mulutu/security-manager/internal/database"
	"github.com/mulutu/security-manager/internal/proto"
	"github.com/nats-io/nats.go"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)

const subjFmt = "logs.%s.%s" // org_id, host_id

// validateToken validates tokens in the format: sm_orgid_timestamp_hostid
// Returns the extracted org_id if valid, empty string if invalid
func validateToken(token string) string {
	// Handle demo token for backwards compatibility
	if token == "sm_tok_demo123" {
		return "demo"
	}

	// Validate production token format: sm_orgid_timestamp_hostid
	re := regexp.MustCompile(`^sm_([^_]+)_[0-9]+_.+$`)
	matches := re.FindStringSubmatch(token)

	if len(matches) >= 2 {
		return matches[1] // Return the org_id
	}

	return "" // Invalid token format
}

// ─── gRPC server implementation ──────────────────────────────────────────

type ingestServer struct {
	proto.UnimplementedAgentIngestServer
	js nats.JetStreamContext
	db *database.DB
}

func (s *ingestServer) Authenticate(ctx context.Context, req *proto.AuthRequest) (*proto.AuthResponse, error) {
	// Extract org_id from token
	extractedOrgID := validateToken(req.Token)
	if extractedOrgID == "" {
		log.Printf("Authentication failed: Invalid token format: %s", req.Token)
		return &proto.AuthResponse{
			Authenticated: false,
			ErrorMessage:  "Invalid token format",
		}, nil
	}

	// Verify that the provided org_id matches the one in the token
	if req.OrgId != extractedOrgID {
		log.Printf("Authentication failed: Org ID mismatch. Provided: %s, Token: %s", req.OrgId, extractedOrgID)
		return &proto.AuthResponse{
			Authenticated: false,
			ErrorMessage:  "Invalid org_id or token",
		}, nil
	}

	// Auto-register the agent if system info is provided
	var agentID string
	var registered bool
	if req.Hostname != "" && req.IpAddress != "" && s.db != nil {
		agent, err := s.db.UpsertAgent(
			req.OrgId,
			req.Hostname, // Use hostname as hostId
			req.Hostname,
			req.IpAddress,
			req.OsType,
			req.OsVersion,
			req.AgentVersion,
			req.Capabilities,
		)
		if err != nil {
			log.Printf("⚠️  Auto-registration failed: %v", err)
			// Don't fail authentication if registration fails
		} else {
			agentID = agent.ID
			registered = true
			log.Printf("✅ Agent auto-registered: %s (%s) - %s %s",
				agent.Name, agent.IPAddress, agent.OSInfo, agent.Status)
		}
	}

	log.Printf("✅ Agent authenticated: org=%s, version=%s, hostname=%s, ip=%s",
		req.OrgId, req.AgentVersion, req.Hostname, req.IpAddress)

	return &proto.AuthResponse{
		Authenticated:            true,
		HeartbeatIntervalSeconds: 30,
		Registered:               registered,
		AgentId:                  agentID,
	}, nil
}

func (s *ingestServer) StreamEvents(stream proto.AgentIngest_StreamEventsServer) error {
	log.Printf("📡 New stream connection established")

	for {
		event, err := stream.Recv()
		if err != nil {
			log.Printf("Stream ended: %v", err)
			break
		}

		// Update agent status to ONLINE when we receive events
		if s.db != nil && event.Stream == "heartbeat" {
			if err := s.db.UpdateAgentStatus(event.OrgId, event.HostId, "ONLINE"); err != nil {
				log.Printf("Warning: failed to update agent status: %v", err)
			}
		}

		log.Printf("📊 Event: %s/%s [%s] %s",
			event.OrgId, event.HostId, event.Stream, event.Message)

		// TODO: Store in ClickHouse
		// TODO: Publish to NATS for real-time processing
	}

	return stream.SendAndClose(&proto.Ack{})
}

func (s *ingestServer) ReceiveCommands(stream proto.AgentIngest_ReceiveCommandsServer) error {
	log.Printf("🎯 New command stream established")

	// Keep the connection alive for bidirectional communication
	for {
		select {
		case <-stream.Context().Done():
			return stream.Context().Err()
		default:
			// TODO: Listen for mitigation commands from the SaaS
			time.Sleep(1 * time.Second)
		}
	}
}

// ─── Main function ────────────────────────────────────────────────────────

func main() {
	log.Printf("🚀 Security Manager Ingest Server v1.0.7")

	// Connect to PostgreSQL database
	db, err := database.Connect()
	if err != nil {
		log.Printf("⚠️  Database connection failed: %v", err)
		log.Printf("🔄 Continuing without database (auto-registration disabled)")
		db = nil
	}
	defer func() {
		if db != nil {
			db.Close()
		}
	}()

	// TODO: Connect to ClickHouse for event storage
	// TODO: Connect to NATS for real-time event streaming

	// Start gRPC server
	port := os.Getenv("GRPC_PORT")
	if port == "" {
		port = "9002"
	}

	lis, err := net.Listen("tcp", ":"+port)
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
	}

	// Create gRPC server with TLS support
	var s *grpc.Server
	if os.Getenv("USE_TLS") == "true" {
		// Load TLS certificates
		cert, err := tls.LoadX509KeyPair("server.crt", "server.key")
		if err != nil {
			log.Fatalf("Failed to load TLS certificates: %v", err)
		}

		creds := credentials.NewServerTLSFromCert(&cert)
		s = grpc.NewServer(grpc.Creds(creds))
	} else {
		s = grpc.NewServer()
	}

	// Register our service
	proto.RegisterAgentIngestServer(s, &ingestServer{
		js: nil, // TODO: Initialize NATS JetStream
		db: db,
	})

	// Graceful shutdown
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGTERM)
	go func() {
		<-c
		log.Printf("🛑 Shutting down gracefully...")
		s.GracefulStop()
	}()

	log.Printf("🎯 gRPC server listening on :%s (TLS: %v)", port, os.Getenv("USE_TLS") == "true")
	if err := s.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
}
