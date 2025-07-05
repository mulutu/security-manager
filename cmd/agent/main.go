package main

import (
	"context"
	"crypto/tls"
	"flag"
	"log"
	"os"
	"os/signal"
	"regexp"
	"syscall"

	pb "github.com/mulutu/security-manager/internal/proto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
)

var (
	token     = flag.String("token", getEnvOrDefault("SM_TOKEN", ""), "authentication token (required)")
	ingestURL = flag.String("ingest", getEnvOrDefault("SM_INGEST_URL", "178.79.139.38:9002"), "gRPC ingest host:port")
	filePath  = flag.String("file", getEnvOrDefault("SM_FILE_PATH", ""), "file to tail")
	useTLS    = flag.Bool("tls", getEnvOrDefault("SM_USE_TLS", "false") == "true", "use TLS for gRPC connection")
	version   = "1.0.0"
)

func main() {
	flag.Parse()

	if *token == "" {
		log.Fatalln("missing -token flag or SM_TOKEN environment variable")
	}

	// Extract org ID and host ID from token (format: sm_orgid_timestamp_hostid)
	orgID, hostID := extractFromToken(*token)
	if orgID == "" {
		log.Fatalln("invalid token format - cannot extract organization ID")
	}
	if hostID == "" {
		// Fallback to hostname if not in token
		if h, _ := os.Hostname(); h != "" {
			hostID = h
		} else {
			log.Fatalln("could not determine hostname from token or system")
		}
	}

	log.Printf("🔧 Extracted from token: org=%s, host=%s", orgID, hostID)

	// Setup gRPC connection with optional TLS
	var opts []grpc.DialOption
	if *useTLS {
		config := &tls.Config{
			ServerName: *ingestURL, // Use the hostname for cert validation
		}
		opts = append(opts, grpc.WithTransportCredentials(credentials.NewTLS(config)))
	} else {
		opts = append(opts, grpc.WithTransportCredentials(insecure.NewCredentials()))
	}

	conn, err := grpc.Dial(*ingestURL, opts...)
	if err != nil {
		log.Fatalf("dial: %v", err)
	}
	defer conn.Close()

	client := pb.NewAgentIngestClient(conn)

	// Authenticate first
	authResp, err := client.Authenticate(context.Background(), &pb.AuthRequest{
		OrgId:        orgID,
		Token:        *token,
		AgentVersion: version,
	})
	if err != nil {
		log.Fatalf("authentication failed: %v", err)
	}
	if !authResp.Authenticated {
		log.Fatalf("authentication rejected: %s", authResp.ErrorMessage)
	}

	log.Printf("✅ Authenticated successfully as %s/%s", orgID, hostID)

	// Start event streaming
	stream, err := client.StreamEvents(context.Background())
	if err != nil {
		log.Fatalf("stream: %v", err)
	}

	// Ctrl-C → graceful shutdown
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	log.Printf("⇢ streaming logs as %s/%s ➜ %s (TLS: %v) …", orgID, hostID, *ingestURL, *useTLS)

	// Start mitigation listener
	mitigator := NewMitigator(ctx, client, orgID, hostID)
	go mitigator.StartMitigationListener()

	if err := runCollector(ctx, stream, orgID, hostID, *filePath, authResp.HeartbeatIntervalSeconds); err != nil {
		log.Fatalf("collector error: %v", err)
	}
}

// extractFromToken extracts org ID and host ID from token
// Token format: sm_orgid_timestamp_hostid
func extractFromToken(token string) (orgID, hostID string) {
	// Pattern: sm_orgid_timestamp_hostid
	re := regexp.MustCompile(`^sm_([^_]+)_[0-9]+_(.+)$`)
	matches := re.FindStringSubmatch(token)

	if len(matches) >= 2 {
		orgID = matches[1]
	}
	if len(matches) >= 3 {
		hostID = matches[2]
	}

	return orgID, hostID
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
