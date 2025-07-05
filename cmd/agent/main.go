package main

import (
	"context"
	"crypto/tls"
	"flag"
	"log"
	"net"
	"os"
	"os/signal"
	"regexp"
	"runtime"
	"strings"
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
	version   = "1.0.6"
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

	// Collect system information for auto-registration
	systemInfo := collectSystemInfo()
	log.Printf("🖥️  System info: %s %s on %s", systemInfo.hostname, systemInfo.osType, systemInfo.ipAddress)

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

	// Authenticate with auto-registration
	authResp, err := client.Authenticate(context.Background(), &pb.AuthRequest{
		OrgId:        orgID,
		Token:        *token,
		AgentVersion: version,
		// Auto-registration fields
		Hostname:     systemInfo.hostname,
		IpAddress:    systemInfo.ipAddress,
		OsType:       systemInfo.osType,
		OsVersion:    systemInfo.osVersion,
		Capabilities: systemInfo.capabilities,
	})
	if err != nil {
		log.Fatalf("authentication failed: %v", err)
	}
	if !authResp.Authenticated {
		log.Fatalf("authentication rejected: %s", authResp.ErrorMessage)
	}

	log.Printf("✅ Authenticated successfully as %s/%s", orgID, hostID)
	if authResp.Registered {
		log.Printf("🎯 Server auto-registered with ID: %s", authResp.AgentId)
	}

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

// SystemInfo holds collected system information
type SystemInfo struct {
	hostname     string
	ipAddress    string
	osType       string
	osVersion    string
	capabilities []string
}

// collectSystemInfo gathers system information for auto-registration
func collectSystemInfo() SystemInfo {
	info := SystemInfo{
		capabilities: []string{"log-monitoring", "file-tailing", "heartbeat"},
	}

	// Get hostname
	if hostname, err := os.Hostname(); err == nil {
		info.hostname = hostname
	} else {
		info.hostname = "unknown"
	}

	// Get primary IP address
	info.ipAddress = getOutboundIP()

	// Get OS information
	info.osType = runtime.GOOS
	switch runtime.GOOS {
	case "linux":
		info.osVersion = getLinuxVersion()
		info.capabilities = append(info.capabilities, "process-monitoring", "network-monitoring", "file-integrity")
	case "windows":
		info.osVersion = "Windows " + runtime.GOARCH
		info.capabilities = append(info.capabilities, "process-monitoring", "event-log-monitoring")
	case "darwin":
		info.osVersion = "macOS " + runtime.GOARCH
		info.capabilities = append(info.capabilities, "process-monitoring", "file-integrity")
	default:
		info.osVersion = runtime.GOOS + " " + runtime.GOARCH
	}

	return info
}

// getOutboundIP gets the preferred outbound IP address
func getOutboundIP() string {
	conn, err := net.Dial("udp", "8.8.8.8:80")
	if err != nil {
		return "unknown"
	}
	defer conn.Close()

	localAddr := conn.LocalAddr().(*net.UDPAddr)
	return localAddr.IP.String()
}

// getLinuxVersion attempts to get Linux distribution version
func getLinuxVersion() string {
	// Try to read /etc/os-release
	if data, err := os.ReadFile("/etc/os-release"); err == nil {
		lines := strings.Split(string(data), "\n")
		for _, line := range lines {
			if strings.HasPrefix(line, "PRETTY_NAME=") {
				// Remove PRETTY_NAME=" and trailing "
				version := strings.TrimPrefix(line, "PRETTY_NAME=")
				version = strings.Trim(version, "\"")
				return version
			}
		}
	}

	// Fallback to kernel version
	if data, err := os.ReadFile("/proc/version"); err == nil {
		version := strings.Fields(string(data))
		if len(version) >= 3 {
			return "Linux " + version[2]
		}
	}

	return "Linux"
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
