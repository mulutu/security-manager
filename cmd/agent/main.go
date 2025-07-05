package main

import (
	"context"
	"crypto/tls"
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/kardianos/service"
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

	// Service management flags
	serviceFlag = flag.String("service", "", "Control the system service (install, uninstall, start, stop)")

	version = "1.0.0"
	logger  service.Logger
)

// Agent represents our service
type Agent struct {
	ctx    context.Context
	cancel context.CancelFunc
}

// Start is called when the service starts
func (a *Agent) Start(s service.Service) error {
	if service.Interactive() {
		logger.Info("Running in terminal.")
	} else {
		logger.Info("Running as service.")
	}

	a.ctx, a.cancel = context.WithCancel(context.Background())
	go a.run()
	return nil
}

// Stop is called when the service stops
func (a *Agent) Stop(s service.Service) error {
	logger.Info("Stopping Security Manager Agent...")
	if a.cancel != nil {
		a.cancel()
	}
	return nil
}

// run contains the main agent logic
func (a *Agent) run() {
	defer func() {
		if r := recover(); r != nil {
			logger.Errorf("Agent crashed: %v", r)
		}
	}()

	if *orgID == "" {
		logger.Error("missing -org flag or SM_ORG_ID environment variable")
		return
	}
	if *token == "" {
		logger.Error("missing -token flag or SM_TOKEN environment variable")
		return
	}
	if *hostID == "" {
		if h, _ := os.Hostname(); h != "" {
			*hostID = h
		} else {
			logger.Error("could not determine hostname, please specify -host")
			return
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
		logger.Errorf("dial failed: %v", err)
		return
	}
	defer conn.Close()

	client := pb.NewAgentIngestClient(conn)

	// Authenticate first
	authResp, err := client.Authenticate(a.ctx, &pb.AuthRequest{
		OrgId:        *orgID,
		Token:        *token,
		AgentVersion: version,
	})
	if err != nil {
		logger.Errorf("authentication failed: %v", err)
		return
	}
	if !authResp.Authenticated {
		logger.Errorf("authentication rejected: %s", authResp.ErrorMessage)
		return
	}

	logger.Infof("✅ Authenticated successfully as %s/%s", *orgID, *hostID)

	// Start event streaming
	stream, err := client.StreamEvents(a.ctx)
	if err != nil {
		logger.Errorf("stream failed: %v", err)
		return
	}

	logger.Infof("⇢ streaming logs as %s/%s ➜ %s (TLS: %v) …", *orgID, *hostID, *ingestURL, *useTLS)
	if err := runCollector(a.ctx, stream, *orgID, *hostID, *filePath, authResp.HeartbeatIntervalSeconds); err != nil {
		logger.Errorf("collector error: %v", err)
		return
	}
}

func main() {
	flag.Parse()

	// Service configuration
	svcConfig := &service.Config{
		Name:        "SecurityManagerAgent",
		DisplayName: "Security Manager Agent",
		Description: "Security Manager monitoring and protection agent",
		Arguments:   []string{"-org", *orgID, "-token", *token, "-ingest", *ingestURL},
	}

	// Create the agent
	agent := &Agent{}

	// Create the service
	s, err := service.New(agent, svcConfig)
	if err != nil {
		log.Fatal(err)
	}

	// Setup logger
	logger, err = s.Logger(nil)
	if err != nil {
		log.Fatal(err)
	}

	// Handle service control commands
	if len(*serviceFlag) != 0 {
		err := service.Control(s, *serviceFlag)
		if err != nil {
			log.Printf("Valid actions: %q\n", service.ControlAction)
			log.Fatal(err)
		}
		return
	}

	// Run the service
	if service.Interactive() {
		// Running in terminal - handle Ctrl+C gracefully
		ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
		defer cancel()

		agent.ctx = ctx
		go agent.run()

		<-ctx.Done()
		logger.Info("Shutting down...")
	} else {
		// Running as a service
		err = s.Run()
		if err != nil {
			logger.Error(err)
		}
	}
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
