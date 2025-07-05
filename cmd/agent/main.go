package main

import (
	"context"
	"crypto/tls"
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"

	pb "github.com/mulutu/security-manager/internal/proto"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"
)

var (
	orgID     = flag.String("org", getEnvOrDefault("SM_ORG_ID", ""), "organisation ID (required)")
	token     = flag.String("token", getEnvOrDefault("SM_TOKEN", ""), "authentication token (required)")
	hostID    = flag.String("host", getEnvOrDefault("SM_HOST_ID", ""), "host ID (default: hostname)")
	ingestURL = flag.String("ingest", getEnvOrDefault("SM_INGEST_URL", "localhost:9002"), "gRPC ingest host:port")
	filePath  = flag.String("file", getEnvOrDefault("SM_FILE_PATH", ""), "file to tail")
	useTLS    = flag.Bool("tls", getEnvOrDefault("SM_USE_TLS", "false") == "true", "use TLS for gRPC connection")
	version   = "1.0.0"
)

func main() {
	flag.Parse()

	if *orgID == "" {
		log.Fatalln("missing -org flag or SM_ORG_ID environment variable")
	}
	if *token == "" {
		log.Fatalln("missing -token flag or SM_TOKEN environment variable")
	}
	if *hostID == "" {
		if h, _ := os.Hostname(); h != "" {
			*hostID = h
		} else {
			log.Fatalln("could not determine hostname, please specify -host")
		}
	}

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
		OrgId:        *orgID,
		Token:        *token,
		AgentVersion: version,
	})
	if err != nil {
		log.Fatalf("authentication failed: %v", err)
	}
	if !authResp.Authenticated {
		log.Fatalf("authentication rejected: %s", authResp.ErrorMessage)
	}

	log.Printf("✅ Authenticated successfully as %s/%s", *orgID, *hostID)

	// Start event streaming
	stream, err := client.StreamEvents(context.Background())
	if err != nil {
		log.Fatalf("stream: %v", err)
	}

	// Ctrl-C → graceful shutdown
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	log.Printf("⇢ streaming logs as %s/%s ➜ %s (TLS: %v) …", *orgID, *hostID, *ingestURL, *useTLS)
	if err := runCollector(ctx, stream, *orgID, *hostID, *filePath, authResp.HeartbeatIntervalSeconds); err != nil {
		log.Fatalf("collector error: %v", err)
	}
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
