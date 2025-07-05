package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"regexp"
	"strconv"
	"sync"
	"time"

	"github.com/mulutu/security-manager/internal/proto"
	"github.com/nats-io/nats.go"
	gproto "google.golang.org/protobuf/proto"
)

// RulesEngine handles security detection and response
type RulesEngine struct {
	js          nats.JetStreamContext
	rules       []DetectionRule
	alertCounts map[string]int
	alertMutex  sync.RWMutex
	ctx         context.Context
	mitigations chan MitigationRequest
}

// DetectionRule defines a security detection rule
type DetectionRule struct {
	ID          string
	Name        string
	Description string
	Severity    string
	Pattern     *regexp.Regexp
	Stream      string
	Threshold   int
	TimeWindow  time.Duration
	Action      string
	Enabled     bool
}

// MitigationRequest represents a mitigation action to be taken
type MitigationRequest struct {
	OrgID     string
	HostID    string
	Action    string
	Target    string
	Duration  int
	Reason    string
	RuleID    string
	RequestID string
}

// NewRulesEngine creates a new rules engine
func NewRulesEngine(ctx context.Context, js nats.JetStreamContext) *RulesEngine {
	engine := &RulesEngine{
		js:          js,
		rules:       getDefaultRules(),
		alertCounts: make(map[string]int),
		ctx:         ctx,
		mitigations: make(chan MitigationRequest, 100),
	}

	// Start mitigation processor
	go engine.processMitigations()

	return engine
}

// StartRulesEngine begins processing events for rule matching
func (re *RulesEngine) StartRulesEngine() {
	log.Printf("🔍 Starting security rules engine with %d rules", len(re.rules))

	// Subscribe to all log events
	sub, err := re.js.PullSubscribe("logs.>", "rules-engine", nats.PullMaxWaiting(128))
	if err != nil {
		log.Fatalf("Failed to subscribe to logs: %v", err)
	}

	for {
		select {
		case <-re.ctx.Done():
			return
		default:
			// Fetch messages in batches
			msgs, err := sub.Fetch(50, nats.MaxWait(1*time.Second))
			if err != nil {
				continue
			}

			for _, msg := range msgs {
				// Parse the log event
				event := new(proto.LogEvent)
				if err := gproto.Unmarshal(msg.Data, event); err != nil {
					msg.Nak()
					continue
				}

				// Process event against rules
				re.processEvent(event)
				msg.Ack()
			}
		}
	}
}

// processEvent checks an event against all detection rules
func (re *RulesEngine) processEvent(event *proto.LogEvent) {
	for _, rule := range re.rules {
		if !rule.Enabled {
			continue
		}

		// Check if rule applies to this stream
		if rule.Stream != "" && rule.Stream != event.Stream {
			continue
		}

		// Check if pattern matches
		if rule.Pattern.MatchString(event.Message) {
			re.handleRuleMatch(rule, event)
		}
	}
}

// handleRuleMatch processes a rule match and determines actions
func (re *RulesEngine) handleRuleMatch(rule DetectionRule, event *proto.LogEvent) {
	alertKey := fmt.Sprintf("%s:%s:%s", rule.ID, event.OrgId, event.HostId)

	re.alertMutex.Lock()
	re.alertCounts[alertKey]++
	count := re.alertCounts[alertKey]
	re.alertMutex.Unlock()

	// Check if threshold is met
	if count >= rule.Threshold {
		log.Printf("🚨 ALERT: Rule %s triggered for %s/%s (count: %d)",
			rule.Name, event.OrgId, event.HostId, count)

		// Send alert
		re.sendAlert(rule, event, count)

		// Execute mitigation action if specified
		if rule.Action != "" {
			re.executeMitigation(rule, event)
		}

		// Reset counter
		re.alertMutex.Lock()
		delete(re.alertCounts, alertKey)
		re.alertMutex.Unlock()
	}
}

// sendAlert sends an alert notification
func (re *RulesEngine) sendAlert(rule DetectionRule, event *proto.LogEvent, count int) {
	alert := map[string]interface{}{
		"rule_id":     rule.ID,
		"rule_name":   rule.Name,
		"severity":    rule.Severity,
		"org_id":      event.OrgId,
		"host_id":     event.HostId,
		"timestamp":   time.Unix(0, event.TsUnixNs),
		"message":     event.Message,
		"stream":      event.Stream,
		"count":       count,
		"description": rule.Description,
	}

	// Publish alert to NATS
	subject := fmt.Sprintf("alerts.%s.%s", event.OrgId, rule.Severity)
	if data, err := json.Marshal(alert); err == nil {
		re.js.PublishAsync(subject, data)
	}

	log.Printf("📢 Alert sent: %s - %s", rule.Name, event.Message)
}

// executeMitigation triggers a mitigation action
func (re *RulesEngine) executeMitigation(rule DetectionRule, event *proto.LogEvent) {
	requestID := fmt.Sprintf("mit_%d", time.Now().UnixNano())

	mitigation := MitigationRequest{
		OrgID:     event.OrgId,
		HostID:    event.HostId,
		Action:    rule.Action,
		Target:    re.extractTarget(rule, event),
		Duration:  30, // Default 30 minutes
		Reason:    fmt.Sprintf("Rule %s triggered", rule.Name),
		RuleID:    rule.ID,
		RequestID: requestID,
	}

	select {
	case re.mitigations <- mitigation:
		log.Printf("🛡️ Mitigation queued: %s for %s/%s", mitigation.Action, mitigation.OrgID, mitigation.HostID)
	default:
		log.Printf("⚠️ Mitigation queue full, dropping request")
	}
}

// processMitigations handles mitigation requests
func (re *RulesEngine) processMitigations() {
	for {
		select {
		case <-re.ctx.Done():
			return
		case mitigation := <-re.mitigations:
			re.sendMitigationCommand(mitigation)
		}
	}
}

// sendMitigationCommand sends a mitigation command to the agent
func (re *RulesEngine) sendMitigationCommand(mitigation MitigationRequest) {
	var protoReq *proto.MitigateRequest

	switch mitigation.Action {
	case "block_ip":
		protoReq = &proto.MitigateRequest{
			RequestId: mitigation.RequestID,
			OrgId:     mitigation.OrgID,
			HostId:    mitigation.HostID,
			Action: &proto.MitigateRequest_BlockIp{
				BlockIp: &proto.BlockIPAction{
					IpAddress:       mitigation.Target,
					DurationMinutes: int32(mitigation.Duration),
				},
			},
		}
	case "kill_process":
		if pid, err := strconv.Atoi(mitigation.Target); err == nil {
			protoReq = &proto.MitigateRequest{
				RequestId: mitigation.RequestID,
				OrgId:     mitigation.OrgID,
				HostId:    mitigation.HostID,
				Action: &proto.MitigateRequest_KillProcess{
					KillProcess: &proto.KillProcessAction{
						Pid:         int32(pid),
						ProcessName: "unknown", // Will be validated by agent
					},
				},
			}
		}
	}

	if protoReq != nil {
		// Send command via NATS
		subject := fmt.Sprintf("commands.%s.%s", mitigation.OrgID, mitigation.HostID)
		if data, err := gproto.Marshal(protoReq); err == nil {
			re.js.PublishAsync(subject, data)
			log.Printf("📤 Mitigation command sent: %s", mitigation.RequestID)
		}
	}
}

// extractTarget extracts the target (IP, PID, etc.) from the event based on the rule
func (re *RulesEngine) extractTarget(rule DetectionRule, event *proto.LogEvent) string {
	switch rule.Action {
	case "block_ip":
		// Extract IP from message using regex
		ipRegex := regexp.MustCompile(`(\d+\.\d+\.\d+\.\d+)`)
		if matches := ipRegex.FindStringSubmatch(event.Message); len(matches) > 1 {
			return matches[1]
		}
	case "kill_process":
		// Extract PID from message
		pidRegex := regexp.MustCompile(`(?:PID|pid)[:=\s]+(\d+)`)
		if matches := pidRegex.FindStringSubmatch(event.Message); len(matches) > 1 {
			return matches[1]
		}
	}
	return ""
}

// getDefaultRules returns the default set of detection rules
func getDefaultRules() []DetectionRule {
	return []DetectionRule{
		{
			ID:          "ssh_brute_force",
			Name:        "SSH Brute Force Attack",
			Description: "Multiple failed SSH login attempts detected",
			Severity:    "critical",
			Pattern:     regexp.MustCompile(`Failed password for .* from (\d+\.\d+\.\d+\.\d+)`),
			Stream:      "auth",
			Threshold:   5,
			TimeWindow:  5 * time.Minute,
			Action:      "block_ip",
			Enabled:     true,
		},
		{
			ID:          "high_cpu_usage",
			Name:        "High CPU Usage",
			Description: "CPU usage exceeds 90%",
			Severity:    "warning",
			Pattern:     regexp.MustCompile(`High CPU usage: (\d+\.\d+)%`),
			Stream:      "system",
			Threshold:   3,
			TimeWindow:  10 * time.Minute,
			Action:      "",
			Enabled:     true,
		},
		{
			ID:          "disk_full",
			Name:        "Disk Space Critical",
			Description: "Disk usage exceeds 85%",
			Severity:    "critical",
			Pattern:     regexp.MustCompile(`High disk usage: (\d+\.\d+)%`),
			Stream:      "system",
			Threshold:   1,
			TimeWindow:  1 * time.Minute,
			Action:      "",
			Enabled:     true,
		},
		{
			ID:          "memory_oom",
			Name:        "Out of Memory",
			Description: "System is running out of memory",
			Severity:    "critical",
			Pattern:     regexp.MustCompile(`Out of memory: Kill process (\d+)`),
			Stream:      "system",
			Threshold:   1,
			TimeWindow:  1 * time.Minute,
			Action:      "",
			Enabled:     true,
		},
		{
			ID:          "sudo_abuse",
			Name:        "Suspicious Sudo Usage",
			Description: "Unusual sudo command patterns detected",
			Severity:    "warning",
			Pattern:     regexp.MustCompile(`sudo:.*COMMAND=(/bin/bash|/bin/sh|rm -rf)`),
			Stream:      "auth",
			Threshold:   3,
			TimeWindow:  5 * time.Minute,
			Action:      "",
			Enabled:     true,
		},
		{
			ID:          "file_modification",
			Name:        "Critical File Modified",
			Description: "Critical system file was modified",
			Severity:    "warning",
			Pattern:     regexp.MustCompile(`File modified: (/etc/passwd|/etc/shadow|/etc/sudoers)`),
			Stream:      "filesystem",
			Threshold:   1,
			TimeWindow:  1 * time.Minute,
			Action:      "",
			Enabled:     true,
		},
		{
			ID:          "network_scan",
			Name:        "Network Port Scan",
			Description: "Potential network scanning activity",
			Severity:    "warning",
			Pattern:     regexp.MustCompile(`Suspicious connection:.*(:22|:3389|:1433|:3306)`),
			Stream:      "network",
			Threshold:   10,
			TimeWindow:  2 * time.Minute,
			Action:      "block_ip",
			Enabled:     true,
		},
		{
			ID:          "process_anomaly",
			Name:        "Suspicious Process",
			Description: "Suspicious process execution detected",
			Severity:    "warning",
			Pattern:     regexp.MustCompile(`Process started:.*(nc|ncat|socat|python.*-c|perl.*-e)`),
			Stream:      "process",
			Threshold:   1,
			TimeWindow:  1 * time.Minute,
			Action:      "",
			Enabled:     true,
		},
	}
}

// Management functions for rules

// AddRule adds a new detection rule
func (re *RulesEngine) AddRule(rule DetectionRule) {
	re.rules = append(re.rules, rule)
	log.Printf("✅ Added detection rule: %s", rule.Name)
}

// DisableRule disables a rule by ID
func (re *RulesEngine) DisableRule(ruleID string) {
	for i, rule := range re.rules {
		if rule.ID == ruleID {
			re.rules[i].Enabled = false
			log.Printf("🔇 Disabled rule: %s", rule.Name)
			return
		}
	}
}

// EnableRule enables a rule by ID
func (re *RulesEngine) EnableRule(ruleID string) {
	for i, rule := range re.rules {
		if rule.ID == ruleID {
			re.rules[i].Enabled = true
			log.Printf("🔊 Enabled rule: %s", rule.Name)
			return
		}
	}
}

// GetRuleStats returns statistics about rule matches
func (re *RulesEngine) GetRuleStats() map[string]interface{} {
	re.alertMutex.RLock()
	defer re.alertMutex.RUnlock()

	stats := map[string]interface{}{
		"total_rules":   len(re.rules),
		"enabled_rules": 0,
		"alert_counts":  make(map[string]int),
		"queue_size":    len(re.mitigations),
	}

	for _, rule := range re.rules {
		if rule.Enabled {
			stats["enabled_rules"] = stats["enabled_rules"].(int) + 1
		}
	}

	for key, count := range re.alertCounts {
		stats["alert_counts"].(map[string]int)[key] = count
	}

	return stats
}
