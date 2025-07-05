package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"syscall"
	"time"

	pb "github.com/mulutu/security-manager/internal/proto"
)

// Mitigator handles security mitigation actions
type Mitigator struct {
	org    string
	host   string
	ctx    context.Context
	client pb.AgentIngestClient
}

// NewMitigator creates a new mitigation handler
func NewMitigator(ctx context.Context, client pb.AgentIngestClient, org, host string) *Mitigator {
	return &Mitigator{
		org:    org,
		host:   host,
		ctx:    ctx,
		client: client,
	}
}

// StartMitigationListener starts listening for mitigation commands
func (m *Mitigator) StartMitigationListener() {
	log.Printf("🛡️ Starting mitigation listener for %s/%s", m.org, m.host)

	for {
		select {
		case <-m.ctx.Done():
			return
		default:
			// Establish command stream
			stream, err := m.client.ReceiveCommands(m.ctx)
			if err != nil {
				log.Printf("Failed to establish command stream: %v", err)
				time.Sleep(5 * time.Second)
				continue
			}

			// Listen for commands
			for {
				select {
				case <-m.ctx.Done():
					return
				default:
					req, err := stream.Recv()
					if err != nil {
						log.Printf("Command stream error: %v", err)
						break
					}

					// Process mitigation request
					go m.processMitigationRequest(stream, req)
				}
			}
		}
	}
}

// processMitigationRequest handles individual mitigation commands
func (m *Mitigator) processMitigationRequest(stream pb.AgentIngest_ReceiveCommandsClient, req *pb.MitigateRequest) {
	log.Printf("🚨 Received mitigation request: %s", req.RequestId)

	var success bool
	var errorMessage string

	// Execute the appropriate mitigation action
	switch action := req.Action.(type) {
	case *pb.MitigateRequest_BlockIp:
		success, errorMessage = m.blockIP(action.BlockIp)
	case *pb.MitigateRequest_KillProcess:
		success, errorMessage = m.killProcess(action.KillProcess)
	default:
		success = false
		errorMessage = "Unknown mitigation action"
	}

	// Send response
	response := &pb.MitigateResponse{
		RequestId:    req.RequestId,
		Success:      success,
		ErrorMessage: errorMessage,
	}

	if err := stream.Send(response); err != nil {
		log.Printf("Failed to send mitigation response: %v", err)
	}

	// Log the action
	status := "SUCCESS"
	if !success {
		status = "FAILED"
	}
	log.Printf("🛡️ Mitigation %s: %s - %s", req.RequestId, status, errorMessage)
}

// blockIP implements IP blocking using iptables
func (m *Mitigator) blockIP(action *pb.BlockIPAction) (bool, string) {
	log.Printf("🚫 Blocking IP: %s for %d minutes", action.IpAddress, action.DurationMinutes)

	// Validate IP address
	if !m.isValidIP(action.IpAddress) {
		return false, "Invalid IP address format"
	}

	// Check if we have iptables
	if !m.hasIptables() {
		return false, "iptables not available"
	}

	// Create iptables rule to block IP
	cmd := exec.Command("iptables", "-I", "INPUT", "-s", action.IpAddress, "-j", "DROP")

	if err := cmd.Run(); err != nil {
		return false, fmt.Sprintf("Failed to add iptables rule: %v", err)
	}

	// Schedule removal if duration is specified
	if action.DurationMinutes > 0 {
		go m.scheduleIPUnblock(action.IpAddress, time.Duration(action.DurationMinutes)*time.Minute)
	}

	return true, fmt.Sprintf("IP %s blocked successfully", action.IpAddress)
}

// killProcess implements process termination
func (m *Mitigator) killProcess(action *pb.KillProcessAction) (bool, string) {
	log.Printf("💀 Killing process: %s (PID: %d)", action.ProcessName, action.Pid)

	// Validate PID
	if action.Pid <= 0 {
		return false, "Invalid PID"
	}

	// Check if process exists and matches name
	if !m.validateProcess(action.Pid, action.ProcessName) {
		return false, "Process not found or name mismatch"
	}

	// Try graceful termination first (SIGTERM)
	process, err := os.FindProcess(int(action.Pid))
	if err != nil {
		return false, fmt.Sprintf("Failed to find process: %v", err)
	}

	if err := process.Signal(syscall.SIGTERM); err != nil {
		return false, fmt.Sprintf("Failed to send SIGTERM: %v", err)
	}

	// Wait 5 seconds for graceful shutdown
	time.Sleep(5 * time.Second)

	// Check if process is still running
	if m.isProcessRunning(action.Pid) {
		// Force kill (SIGKILL)
		if err := process.Signal(syscall.SIGKILL); err != nil {
			return false, fmt.Sprintf("Failed to send SIGKILL: %v", err)
		}

		// Wait a bit more and verify
		time.Sleep(2 * time.Second)
		if m.isProcessRunning(action.Pid) {
			return false, "Process still running after SIGKILL"
		}
	}

	return true, fmt.Sprintf("Process %s (PID: %d) terminated successfully", action.ProcessName, action.Pid)
}

// Helper functions
func (m *Mitigator) isValidIP(ip string) bool {
	// Basic IP validation
	parts := strings.Split(ip, ".")
	if len(parts) != 4 {
		return false
	}

	for _, part := range parts {
		if num, err := strconv.Atoi(part); err != nil || num < 0 || num > 255 {
			return false
		}
	}

	return true
}

func (m *Mitigator) hasIptables() bool {
	cmd := exec.Command("which", "iptables")
	return cmd.Run() == nil
}

func (m *Mitigator) scheduleIPUnblock(ip string, duration time.Duration) {
	timer := time.NewTimer(duration)
	defer timer.Stop()

	select {
	case <-timer.C:
		// Remove the iptables rule
		cmd := exec.Command("iptables", "-D", "INPUT", "-s", ip, "-j", "DROP")
		if err := cmd.Run(); err != nil {
			log.Printf("Failed to remove iptables rule for %s: %v", ip, err)
		} else {
			log.Printf("🔓 IP %s unblocked after %v", ip, duration)
		}
	case <-m.ctx.Done():
		return
	}
}

func (m *Mitigator) validateProcess(pid int32, expectedName string) bool {
	// Read process name from /proc/PID/comm
	commPath := fmt.Sprintf("/proc/%d/comm", pid)
	data, err := os.ReadFile(commPath)
	if err != nil {
		return false
	}

	actualName := strings.TrimSpace(string(data))
	return actualName == expectedName
}

func (m *Mitigator) isProcessRunning(pid int32) bool {
	// Check if process exists
	process, err := os.FindProcess(int(pid))
	if err != nil {
		return false
	}

	// Send signal 0 to check if process is alive
	err = process.Signal(syscall.Signal(0))
	return err == nil
}

// Additional mitigation functions for future use

// quarantineFile moves a file to quarantine directory
func (m *Mitigator) quarantineFile(filePath string) (bool, string) {
	quarantineDir := "/var/quarantine"

	// Create quarantine directory if it doesn't exist
	if err := os.MkdirAll(quarantineDir, 0700); err != nil {
		return false, fmt.Sprintf("Failed to create quarantine directory: %v", err)
	}

	// Generate unique quarantine filename
	timestamp := time.Now().Format("20060102_150405")
	quarantinePath := fmt.Sprintf("%s/%s_%s", quarantineDir, timestamp, strings.ReplaceAll(filePath, "/", "_"))

	// Move file to quarantine
	if err := os.Rename(filePath, quarantinePath); err != nil {
		return false, fmt.Sprintf("Failed to quarantine file: %v", err)
	}

	log.Printf("📦 File quarantined: %s -> %s", filePath, quarantinePath)
	return true, fmt.Sprintf("File quarantined successfully: %s", quarantinePath)
}

// isolateHost implements network isolation
func (m *Mitigator) isolateHost() (bool, string) {
	log.Printf("🔒 Isolating host from network...")

	// Block all outgoing traffic except essential services
	rules := [][]string{
		{"iptables", "-P", "OUTPUT", "DROP"},
		{"iptables", "-I", "OUTPUT", "-o", "lo", "-j", "ACCEPT"},
		{"iptables", "-I", "OUTPUT", "-p", "tcp", "--dport", "22", "-j", "ACCEPT"},   // Keep SSH
		{"iptables", "-I", "OUTPUT", "-p", "tcp", "--dport", "9002", "-j", "ACCEPT"}, // Keep agent connection
	}

	for _, rule := range rules {
		cmd := exec.Command(rule[0], rule[1:]...)
		if err := cmd.Run(); err != nil {
			return false, fmt.Sprintf("Failed to apply isolation rule: %v", err)
		}
	}

	return true, "Host isolated successfully"
}

// restoreNetwork removes network isolation
func (m *Mitigator) restoreNetwork() (bool, string) {
	log.Printf("🔓 Restoring network access...")

	// Flush OUTPUT chain and restore default policy
	rules := [][]string{
		{"iptables", "-P", "OUTPUT", "ACCEPT"},
		{"iptables", "-F", "OUTPUT"},
	}

	for _, rule := range rules {
		cmd := exec.Command(rule[0], rule[1:]...)
		if err := cmd.Run(); err != nil {
			return false, fmt.Sprintf("Failed to restore network: %v", err)
		}
	}

	return true, "Network access restored successfully"
}

// disableService stops and disables a systemd service
func (m *Mitigator) disableService(serviceName string) (bool, string) {
	log.Printf("🛑 Disabling service: %s", serviceName)

	// Stop the service
	cmd := exec.Command("systemctl", "stop", serviceName)
	if err := cmd.Run(); err != nil {
		return false, fmt.Sprintf("Failed to stop service: %v", err)
	}

	// Disable the service
	cmd = exec.Command("systemctl", "disable", serviceName)
	if err := cmd.Run(); err != nil {
		return false, fmt.Sprintf("Failed to disable service: %v", err)
	}

	return true, fmt.Sprintf("Service %s stopped and disabled", serviceName)
}

// createFirewallRule adds a custom firewall rule
func (m *Mitigator) createFirewallRule(chain, rule string) (bool, string) {
	log.Printf("🔥 Creating firewall rule: %s", rule)

	// Parse and execute the rule
	parts := strings.Fields(rule)
	if len(parts) < 2 {
		return false, "Invalid firewall rule format"
	}

	cmd := exec.Command("iptables", append([]string{"-I", chain}, parts...)...)
	if err := cmd.Run(); err != nil {
		return false, fmt.Sprintf("Failed to create firewall rule: %v", err)
	}

	return true, fmt.Sprintf("Firewall rule created: %s", rule)
}
