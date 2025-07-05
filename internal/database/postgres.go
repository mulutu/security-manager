package database

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	_ "github.com/lib/pq"
)

// DB holds the database connection
type DB struct {
	conn *sql.DB
}

// Agent represents an agent in the database
type Agent struct {
	ID             string    `json:"id"`
	HostID         string    `json:"hostId"`
	OrganizationID string    `json:"organizationId"`
	Name           string    `json:"name"`
	Version        string    `json:"version"`
	Status         string    `json:"status"`
	LastSeen       time.Time `json:"lastSeen"`
	IPAddress      string    `json:"ipAddress"`
	OSInfo         string    `json:"osInfo"`
	Capabilities   []string  `json:"capabilities"`
	CreatedAt      time.Time `json:"createdAt"`
	UpdatedAt      time.Time `json:"updatedAt"`
}

// Connect establishes a connection to PostgreSQL
func Connect() (*DB, error) {
	// Get database URL from environment
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		// Default for development
		databaseURL = "postgresql://security_manager_admin:M@gar1ta@2024!$@localhost:5433/security_manager?sslmode=disable&schema=public"
	}

	conn, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}

	// Test the connection
	if err := conn.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	log.Printf("✅ Connected to PostgreSQL database")
	return &DB{conn: conn}, nil
}

// Close closes the database connection
func (db *DB) Close() error {
	return db.conn.Close()
}

// UpsertAgent creates or updates an agent record
func (db *DB) UpsertAgent(orgID, hostID, hostname, ipAddress, osType, osVersion, agentVersion string, capabilities []string) (*Agent, error) {
	// Convert capabilities to JSON array string for PostgreSQL
	capabilitiesJSON, err := json.Marshal(capabilities)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal capabilities: %w", err)
	}

	// Use hostname as name if provided, otherwise use hostID
	name := hostname
	if name == "" {
		name = hostID
	}

	// Build OS info string
	osInfo := osType
	if osVersion != "" {
		osInfo = fmt.Sprintf("%s (%s)", osType, osVersion)
	}

	query := `
		INSERT INTO "Agent" (id, "hostId", "organizationId", name, version, status, "lastSeen", "ipAddress", "osInfo", capabilities, "createdAt", "updatedAt")
		VALUES (gen_random_uuid(), $1, $2, $3, $4, 'ONLINE', NOW(), $5, $6, $7, NOW(), NOW())
		ON CONFLICT ("organizationId", "hostId")
		DO UPDATE SET
			name = EXCLUDED.name,
			version = EXCLUDED.version,
			status = 'ONLINE',
			"lastSeen" = NOW(),
			"ipAddress" = EXCLUDED."ipAddress",
			"osInfo" = EXCLUDED."osInfo",
			capabilities = EXCLUDED.capabilities,
			"updatedAt" = NOW()
		RETURNING id, "hostId", "organizationId", name, version, status, "lastSeen", "ipAddress", "osInfo", capabilities, "createdAt", "updatedAt"
	`

	var agent Agent
	var capabilitiesStr string
	err = db.conn.QueryRow(query, hostID, orgID, name, agentVersion, ipAddress, osInfo, string(capabilitiesJSON)).Scan(
		&agent.ID,
		&agent.HostID,
		&agent.OrganizationID,
		&agent.Name,
		&agent.Version,
		&agent.Status,
		&agent.LastSeen,
		&agent.IPAddress,
		&agent.OSInfo,
		&capabilitiesStr,
		&agent.CreatedAt,
		&agent.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to upsert agent: %w", err)
	}

	// Parse capabilities back from JSON
	if err := json.Unmarshal([]byte(capabilitiesStr), &agent.Capabilities); err != nil {
		log.Printf("Warning: failed to parse capabilities: %v", err)
		agent.Capabilities = capabilities // fallback to original
	}

	log.Printf("✅ Agent upserted: %s (%s) - %s", agent.Name, agent.IPAddress, agent.Status)
	return &agent, nil
}

// UpdateAgentStatus updates the agent's status and last seen time
func (db *DB) UpdateAgentStatus(orgID, hostID, status string) error {
	query := `
		UPDATE "Agent" 
		SET status = $1, "lastSeen" = NOW(), "updatedAt" = NOW()
		WHERE "organizationId" = $2 AND "hostId" = $3
	`

	result, err := db.conn.Exec(query, strings.ToUpper(status), orgID, hostID)
	if err != nil {
		return fmt.Errorf("failed to update agent status: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rowsAffected == 0 {
		return fmt.Errorf("agent not found: %s/%s", orgID, hostID)
	}

	log.Printf("✅ Agent status updated: %s/%s -> %s", orgID, hostID, status)
	return nil
}

// GetAgent retrieves an agent by organization and host ID
func (db *DB) GetAgent(orgID, hostID string) (*Agent, error) {
	query := `
		SELECT id, "hostId", "organizationId", name, version, status, "lastSeen", "ipAddress", "osInfo", capabilities, "createdAt", "updatedAt"
		FROM "Agent"
		WHERE "organizationId" = $1 AND "hostId" = $2
	`

	var agent Agent
	var capabilitiesStr string
	err := db.conn.QueryRow(query, orgID, hostID).Scan(
		&agent.ID,
		&agent.HostID,
		&agent.OrganizationID,
		&agent.Name,
		&agent.Version,
		&agent.Status,
		&agent.LastSeen,
		&agent.IPAddress,
		&agent.OSInfo,
		&capabilitiesStr,
		&agent.CreatedAt,
		&agent.UpdatedAt,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil // Agent not found
		}
		return nil, fmt.Errorf("failed to get agent: %w", err)
	}

	// Parse capabilities from JSON
	if err := json.Unmarshal([]byte(capabilitiesStr), &agent.Capabilities); err != nil {
		log.Printf("Warning: failed to parse capabilities: %v", err)
		agent.Capabilities = []string{} // fallback to empty array
	}

	return &agent, nil
}
