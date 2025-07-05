package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"time"

	pb "github.com/mulutu/security-manager/internal/proto"
)

// SecurityCollector handles Linux-specific security event collection
type SecurityCollector struct {
	stream   pb.AgentIngest_StreamEventsClient
	org      string
	host     string
	ctx      context.Context
	patterns map[string]*regexp.Regexp
}

// NewSecurityCollector creates a new Linux security collector
func NewSecurityCollector(ctx context.Context, stream pb.AgentIngest_StreamEventsClient, org, host string) *SecurityCollector {
	return &SecurityCollector{
		stream: stream,
		org:    org,
		host:   host,
		ctx:    ctx,
		patterns: map[string]*regexp.Regexp{
			"ssh_fail":     regexp.MustCompile(`Failed password for .* from (\d+\.\d+\.\d+\.\d+)`),
			"ssh_success":  regexp.MustCompile(`Accepted password for (\w+) from (\d+\.\d+\.\d+\.\d+)`),
			"sudo_usage":   regexp.MustCompile(`sudo:\s+(\w+) : TTY=(\w+) ; PWD=([^;]+) ; USER=(\w+) ; COMMAND=(.+)`),
			"login_fail":   regexp.MustCompile(`authentication failure.*user=(\w+)`),
			"process_kill": regexp.MustCompile(`Killed process (\d+) \((.+)\)`),
			"disk_full":    regexp.MustCompile(`No space left on device`),
			"memory_oom":   regexp.MustCompile(`Out of memory: Kill process (\d+) \((.+)\)`),
			"network_drop": regexp.MustCompile(`DROP.*SRC=(\d+\.\d+\.\d+\.\d+).*DST=(\d+\.\d+\.\d+\.\d+)`),
		},
	}
}

// StartCollection begins collecting security events from multiple sources
func (sc *SecurityCollector) StartCollection() {
	log.Printf("🔍 Starting Linux security collection for %s/%s", sc.org, sc.host)

	// Start multiple collectors concurrently
	go sc.collectSystemdJournal()
	go sc.collectAuthLogs()
	go sc.collectProcessEvents()
	go sc.collectNetworkEvents()
	go sc.collectSystemMetrics()
	go sc.collectFileSystemEvents()
}

// collectSystemdJournal monitors systemd journal for security events
func (sc *SecurityCollector) collectSystemdJournal() {
	log.Printf("📋 Starting systemd journal monitoring...")

	// Follow journal from now
	cmd := exec.CommandContext(sc.ctx, "journalctl", "-f", "-o", "json", "--since", "now")
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		log.Printf("Failed to start journalctl: %v", err)
		return
	}

	if err := cmd.Start(); err != nil {
		log.Printf("Failed to start journalctl: %v", err)
		return
	}

	scanner := bufio.NewScanner(stdout)
	for scanner.Scan() {
		select {
		case <-sc.ctx.Done():
			return
		default:
			var entry map[string]interface{}
			if err := json.Unmarshal(scanner.Bytes(), &entry); err != nil {
				continue
			}

			// Extract relevant fields
			message := getString(entry, "MESSAGE")
			unit := getString(entry, "_SYSTEMD_UNIT")
			priority := getString(entry, "PRIORITY")

			// Calculate severity
			severity := sc.calculateSeverity(message, unit, priority)

			// Send event
			sc.sendEvent("systemd", message, map[string]string{
				"unit":     unit,
				"priority": priority,
				"severity": severity,
				"source":   "journalctl",
			})
		}
	}
}

// collectAuthLogs monitors authentication events
func (sc *SecurityCollector) collectAuthLogs() {
	authPaths := []string{
		"/var/log/auth.log",
		"/var/log/secure",
		"/var/log/messages",
	}

	for _, path := range authPaths {
		if _, err := os.Stat(path); err == nil {
			go sc.tailSecurityFile(path, "auth")
			break
		}
	}
}

// collectProcessEvents monitors process creation/termination
func (sc *SecurityCollector) collectProcessEvents() {
	log.Printf("⚙️ Starting process monitoring...")

	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	var lastProcesses map[int]string

	for {
		select {
		case <-sc.ctx.Done():
			return
		case <-ticker.C:
			currentProcesses := sc.getProcessList()

			if lastProcesses != nil {
				// Check for new processes
				for pid, name := range currentProcesses {
					if _, exists := lastProcesses[pid]; !exists {
						sc.sendEvent("process", fmt.Sprintf("Process started: %s (PID: %d)", name, pid), map[string]string{
							"event_type": "process_start",
							"pid":        strconv.Itoa(pid),
							"process":    name,
							"severity":   "info",
						})
					}
				}

				// Check for terminated processes
				for pid, name := range lastProcesses {
					if _, exists := currentProcesses[pid]; !exists {
						sc.sendEvent("process", fmt.Sprintf("Process terminated: %s (PID: %d)", name, pid), map[string]string{
							"event_type": "process_end",
							"pid":        strconv.Itoa(pid),
							"process":    name,
							"severity":   "info",
						})
					}
				}
			}

			lastProcesses = currentProcesses
		}
	}
}

// collectNetworkEvents monitors network connections
func (sc *SecurityCollector) collectNetworkEvents() {
	log.Printf("🌐 Starting network monitoring...")

	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-sc.ctx.Done():
			return
		case <-ticker.C:
			// Monitor network connections
			connections := sc.getNetworkConnections()
			for _, conn := range connections {
				if sc.isSuspiciousConnection(conn) {
					sc.sendEvent("network", fmt.Sprintf("Suspicious connection: %s", conn), map[string]string{
						"event_type": "suspicious_connection",
						"connection": conn,
						"severity":   "warning",
					})
				}
			}
		}
	}
}

// collectSystemMetrics monitors system resource usage
func (sc *SecurityCollector) collectSystemMetrics() {
	log.Printf("📊 Starting system metrics collection...")

	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-sc.ctx.Done():
			return
		case <-ticker.C:
			metrics := sc.getSystemMetrics()

			// Check for critical resource usage
			if metrics.CPUUsage > 90 {
				sc.sendEvent("system", fmt.Sprintf("High CPU usage: %.1f%%", metrics.CPUUsage), map[string]string{
					"event_type": "high_cpu",
					"cpu_usage":  fmt.Sprintf("%.1f", metrics.CPUUsage),
					"severity":   "warning",
				})
			}

			if metrics.MemoryUsage > 90 {
				sc.sendEvent("system", fmt.Sprintf("High memory usage: %.1f%%", metrics.MemoryUsage), map[string]string{
					"event_type":   "high_memory",
					"memory_usage": fmt.Sprintf("%.1f", metrics.MemoryUsage),
					"severity":     "warning",
				})
			}

			if metrics.DiskUsage > 85 {
				sc.sendEvent("system", fmt.Sprintf("High disk usage: %.1f%%", metrics.DiskUsage), map[string]string{
					"event_type": "high_disk",
					"disk_usage": fmt.Sprintf("%.1f", metrics.DiskUsage),
					"severity":   "critical",
				})
			}
		}
	}
}

// collectFileSystemEvents monitors file system changes
func (sc *SecurityCollector) collectFileSystemEvents() {
	log.Printf("📁 Starting filesystem monitoring...")

	// Monitor critical directories
	criticalPaths := []string{
		"/etc/passwd",
		"/etc/shadow",
		"/etc/sudoers",
		"/etc/ssh/sshd_config",
		"/var/log",
		"/tmp",
	}

	for _, path := range criticalPaths {
		go sc.monitorFile(path)
	}
}

// tailSecurityFile tails a file and analyzes for security events
func (sc *SecurityCollector) tailSecurityFile(path, stream string) {
	log.Printf("📄 Tailing security file: %s", path)

	file, err := os.Open(path)
	if err != nil {
		log.Printf("Failed to open %s: %v", path, err)
		return
	}
	defer file.Close()

	// Seek to end
	file.Seek(0, 2)
	reader := bufio.NewReader(file)

	for {
		select {
		case <-sc.ctx.Done():
			return
		default:
			line, err := reader.ReadString('\n')
			if err != nil {
				time.Sleep(100 * time.Millisecond)
				continue
			}

			// Analyze line for security patterns
			severity, eventType := sc.analyzeSecurityEvent(line)

			sc.sendEvent(stream, strings.TrimSpace(line), map[string]string{
				"file":       path,
				"severity":   severity,
				"event_type": eventType,
				"source":     "file_tail",
			})
		}
	}
}

// Helper functions
func (sc *SecurityCollector) getProcessList() map[int]string {
	processes := make(map[int]string)

	cmd := exec.Command("ps", "axo", "pid,comm")
	output, err := cmd.Output()
	if err != nil {
		return processes
	}

	lines := strings.Split(string(output), "\n")
	for _, line := range lines[1:] { // Skip header
		fields := strings.Fields(line)
		if len(fields) >= 2 {
			if pid, err := strconv.Atoi(fields[0]); err == nil {
				processes[pid] = fields[1]
			}
		}
	}

	return processes
}

func (sc *SecurityCollector) getNetworkConnections() []string {
	cmd := exec.Command("netstat", "-tuln")
	output, err := cmd.Output()
	if err != nil {
		return nil
	}

	return strings.Split(string(output), "\n")
}

func (sc *SecurityCollector) isSuspiciousConnection(conn string) bool {
	// Check for suspicious patterns
	suspiciousPatterns := []string{
		":22 ",   // SSH connections
		":3389 ", // RDP
		":1433 ", // SQL Server
		":3306 ", // MySQL
	}

	for _, pattern := range suspiciousPatterns {
		if strings.Contains(conn, pattern) && strings.Contains(conn, "LISTEN") {
			return true
		}
	}

	return false
}

type SystemMetrics struct {
	CPUUsage    float64
	MemoryUsage float64
	DiskUsage   float64
}

func (sc *SecurityCollector) getSystemMetrics() SystemMetrics {
	metrics := SystemMetrics{}

	// Get CPU usage
	if output, err := exec.Command("top", "-bn1").Output(); err == nil {
		lines := strings.Split(string(output), "\n")
		for _, line := range lines {
			if strings.Contains(line, "Cpu(s)") {
				// Parse CPU usage from top output
				if matches := regexp.MustCompile(`(\d+\.\d+)%us`).FindStringSubmatch(line); len(matches) > 1 {
					if usage, err := strconv.ParseFloat(matches[1], 64); err == nil {
						metrics.CPUUsage = usage
					}
				}
				break
			}
		}
	}

	// Get memory usage
	if output, err := exec.Command("free", "-m").Output(); err == nil {
		lines := strings.Split(string(output), "\n")
		if len(lines) > 1 {
			fields := strings.Fields(lines[1])
			if len(fields) >= 3 {
				if total, err := strconv.ParseFloat(fields[1], 64); err == nil {
					if used, err := strconv.ParseFloat(fields[2], 64); err == nil {
						metrics.MemoryUsage = (used / total) * 100
					}
				}
			}
		}
	}

	// Get disk usage
	if output, err := exec.Command("df", "-h", "/").Output(); err == nil {
		lines := strings.Split(string(output), "\n")
		if len(lines) > 1 {
			fields := strings.Fields(lines[1])
			if len(fields) >= 5 {
				usageStr := strings.TrimSuffix(fields[4], "%")
				if usage, err := strconv.ParseFloat(usageStr, 64); err == nil {
					metrics.DiskUsage = usage
				}
			}
		}
	}

	return metrics
}

func (sc *SecurityCollector) monitorFile(path string) {
	var lastStat os.FileInfo

	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-sc.ctx.Done():
			return
		case <-ticker.C:
			if stat, err := os.Stat(path); err == nil {
				if lastStat != nil && stat.ModTime() != lastStat.ModTime() {
					sc.sendEvent("filesystem", fmt.Sprintf("File modified: %s", path), map[string]string{
						"event_type": "file_modified",
						"file_path":  path,
						"severity":   "info",
					})
				}
				lastStat = stat
			}
		}
	}
}

func (sc *SecurityCollector) analyzeSecurityEvent(line string) (severity, eventType string) {
	// Default values
	severity = "info"
	eventType = "unknown"

	// Check against security patterns
	for pattern, regex := range sc.patterns {
		if regex.MatchString(line) {
			eventType = pattern
			switch pattern {
			case "ssh_fail", "login_fail":
				severity = "warning"
			case "process_kill", "memory_oom":
				severity = "critical"
			case "disk_full":
				severity = "critical"
			case "network_drop":
				severity = "warning"
			case "ssh_success", "sudo_usage":
				severity = "info"
			}
			break
		}
	}

	return severity, eventType
}

func (sc *SecurityCollector) calculateSeverity(message, unit, priority string) string {
	// Convert systemd priority to severity
	switch priority {
	case "0", "1", "2": // Emergency, Alert, Critical
		return "critical"
	case "3", "4": // Error, Warning
		return "warning"
	case "5", "6": // Notice, Info
		return "info"
	default:
		return "info"
	}
}

func (sc *SecurityCollector) sendEvent(stream, message string, labels map[string]string) {
	err := sc.stream.Send(&pb.LogEvent{
		OrgId:    sc.org,
		HostId:   sc.host,
		TsUnixNs: time.Now().UnixNano(),
		Stream:   stream,
		Message:  message,
		Labels:   labels,
	})
	if err != nil {
		log.Printf("Failed to send event: %v", err)
	}
}

func getString(m map[string]interface{}, key string) string {
	if val, ok := m[key]; ok {
		if str, ok := val.(string); ok {
			return str
		}
	}
	return ""
}
