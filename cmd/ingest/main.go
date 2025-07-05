package main

import (
	"context"
	"crypto/tls"
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

	// "github.com/nats-io/nats.go" // Temporarily disabled for Go 1.18 compatibility
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/status"
	gproto "google.golang.org/protobuf/proto" // alias to avoid name clash
)

const subjFmt = "logs.%s.%s" // org_id, host_id

// Simple token validation (replace with proper auth service)
var validTokens = map[string]string{
	"demo": "sm_tok_demo123", // org_id -> token
}

// ─── gRPC server implementation ──────────────────────────────────────────

type ingestServer struct {
	proto.UnimplementedAgentIngestServer
	js nats.JetStreamContext
}

func (s *ingestServer) Authenticate(ctx context.Context, req *proto.AuthRequest) (*proto.AuthResponse, error) {
	// Validate token
	expectedToken, exists := validTokens[req.OrgId]
	if !exists || expectedToken != req.Token {
		return &proto.AuthResponse{
			Authenticated: false,
			ErrorMessage:  "Invalid org_id or token",
		}, nil
	}

	log.Printf("Agent authenticated: org=%s, version=%s", req.OrgId, req.AgentVersion)
	return &proto.AuthResponse{
		Authenticated:            true,
		HeartbeatIntervalSeconds: 30,
	}, nil
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

func (s *ingestServer) ReceiveCommands(stream proto.AgentIngest_ReceiveCommandsServer) error {
	// Get client context for organization and host identification
	ctx := stream.Context()

	// Extract org_id and host_id from context metadata (simplified for now)
	// In production, this would come from authenticated session
	orgID := "demo"     // TODO: Extract from authenticated context
	hostID := "unknown" // TODO: Extract from authenticated context

	log.Printf("🔗 Command stream established for %s/%s", orgID, hostID)

	// Subscribe to commands for this specific agent
	subject := fmt.Sprintf("commands.%s.%s", orgID, hostID)
	sub, err := s.js.PullSubscribe(subject, fmt.Sprintf("agent-%s-%s", orgID, hostID))
	if err != nil {
		return status.Errorf(codes.Internal, "failed to subscribe to commands: %v", err)
	}
	defer sub.Unsubscribe()

	// Handle bidirectional streaming
	go func() {
		// Listen for responses from agent
		for {
			resp, err := stream.Recv()
			if err != nil {
				log.Printf("Command stream recv error: %v", err)
				return
			}

			// Log mitigation response
			status := "SUCCESS"
			if !resp.Success {
				status = "FAILED"
			}
			log.Printf("📥 Mitigation response %s: %s - %s", resp.RequestId, status, resp.ErrorMessage)

			// Store response in ClickHouse for audit trail
			// TODO: Implement audit logging
		}
	}()

	// Send commands to agent
	for {
		select {
		case <-ctx.Done():
			return nil
		default:
			// Fetch pending commands
			msgs, err := sub.Fetch(10, nats.MaxWait(1*time.Second))
			if err != nil {
				continue
			}

			for _, msg := range msgs {
				// Parse command
				var cmd proto.MitigateRequest
				if err := gproto.Unmarshal(msg.Data, &cmd); err != nil {
					msg.Nak()
					continue
				}

				// Send command to agent
				if err := stream.Send(&cmd); err != nil {
					log.Printf("Failed to send command to agent: %v", err)
					msg.Nak()
					return err
				}

				log.Printf("📤 Command sent to agent: %s", cmd.RequestId)
				msg.Ack()
			}
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

	// 2️⃣  ClickHouse + Create Tables
	ch, err := clickhouse.Open(&clickhouse.Options{
		Addr: []string{getEnv("CLICKHOUSE_ADDR", "localhost:9000")},
	})
	if err != nil {
		log.Fatalf("clickhouse: %v", err)
	}

	// Create tables if they don't exist
	if err := createTables(ctx, ch); err != nil {
		log.Fatalf("create tables: %v", err)
	}

	// 3️⃣  gRPC server with TLS
	lis, err := net.Listen("tcp", ":9002")
	if err != nil {
		log.Fatalf("listen: %v", err)
	}

	var grpcSrv *grpc.Server
	if getEnv("TLS_ENABLED", "false") == "true" {
		// Load TLS certificates
		cert, err := tls.LoadX509KeyPair(
			getEnv("TLS_CERT_FILE", "server.crt"),
			getEnv("TLS_KEY_FILE", "server.key"),
		)
		if err != nil {
			log.Fatalf("load TLS certs: %v", err)
		}

		creds := credentials.NewTLS(&tls.Config{
			Certificates: []tls.Certificate{cert},
		})
		grpcSrv = grpc.NewServer(grpc.Creds(creds))
		log.Println("ingest gRPC listening on :9002 with TLS")
	} else {
		grpcSrv = grpc.NewServer()
		log.Println("ingest gRPC listening on :9002 (insecure)")
	}

	proto.RegisterAgentIngestServer(grpcSrv, &ingestServer{js: js})

	go func() {
		if err := grpcSrv.Serve(lis); err != nil {
			log.Fatalf("serve: %v", err)
		}
	}()

	// 4️⃣  Rules Engine for threat detection
	rulesEngine := NewRulesEngine(ctx, js)
	go rulesEngine.StartRulesEngine()

	// 5️⃣  JS → ClickHouse sink (runs until ctx cancelled)
	go clickhouseSink(ctx, js, ch)

	<-ctx.Done()
	log.Println("shutdown…")
	grpcSrv.GracefulStop()
	nc.Drain()
}

// ─── helper routines ─────────────────────────────────────────────────────

func createTables(ctx context.Context, ch clickhouse.Conn) error {
	queries := []string{
		`CREATE TABLE IF NOT EXISTS events (
			org_id String,
			host_id String,
			ts DateTime64(9),
			stream String,
			message String,
			labels Map(String, String),
			severity String DEFAULT 'info'
		) ENGINE = MergeTree()
		PARTITION BY toYYYYMM(ts)
		ORDER BY (org_id, host_id, ts)`,

		`CREATE TABLE IF NOT EXISTS agent_heartbeats (
			org_id String,
			host_id String,
			ts DateTime64(9),
			agent_version String,
			status String
		) ENGINE = MergeTree()
		PARTITION BY toYYYYMM(ts)
		ORDER BY (org_id, host_id, ts)`,

		`CREATE TABLE IF NOT EXISTS alerts (
			alert_id String,
			rule_id String,
			rule_name String,
			org_id String,
			host_id String,
			ts DateTime64(9),
			severity String,
			message String,
			count UInt32,
			status String DEFAULT 'active'
		) ENGINE = MergeTree()
		PARTITION BY toYYYYMM(ts)
		ORDER BY (org_id, severity, ts)`,

		`CREATE TABLE IF NOT EXISTS mitigations (
			request_id String,
			org_id String,
			host_id String,
			ts DateTime64(9),
			action String,
			target String,
			duration_minutes UInt32,
			success Bool,
			error_message String,
			rule_id String
		) ENGINE = MergeTree()
		PARTITION BY toYYYYMM(ts)
		ORDER BY (org_id, host_id, ts)`,

		`CREATE TABLE IF NOT EXISTS system_metrics (
			org_id String,
			host_id String,
			ts DateTime64(9),
			cpu_usage Float64,
			memory_usage Float64,
			disk_usage Float64,
			network_in UInt64,
			network_out UInt64
		) ENGINE = MergeTree()
		PARTITION BY toYYYYMM(ts)
		ORDER BY (org_id, host_id, ts)`,
	}

	for _, query := range queries {
		if err := ch.Exec(ctx, query); err != nil {
			return fmt.Errorf("create table: %w", err)
		}
	}
	log.Println("ClickHouse tables created/verified")
	return nil
}

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
			if err := batch.Send(); err != nil {
				log.Printf("clickhouse batch error: %v", err)
			}
		}
	}
}

func getEnv(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}
