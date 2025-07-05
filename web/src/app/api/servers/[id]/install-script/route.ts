import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth/next'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const session = await getServerSession(authOptions)
    
    console.log('GET /api/servers/[id]/install-script - Session:', JSON.stringify(session, null, 2))
    
    if (!session?.user) {
      return NextResponse.json({ error: 'Not authenticated' }, { status: 401 })
    }

    // If user doesn't have an organization, try to get it from the database
    let organizationId = session.user.organizationId
    
    if (!organizationId && session.user.id) {
      const userWithOrg = await prisma.user.findUnique({
        where: { id: session.user.id },
        include: { organization: true }
      })
      
      if (userWithOrg?.organization) {
        organizationId = userWithOrg.organization.id
      }
    }

    if (!organizationId) {
      return NextResponse.json({ error: 'No organization found. Please complete your setup.' }, { status: 403 })
    }

    // Get the server details
    const server = await prisma.agent.findFirst({
      where: {
        id: id,
        organizationId: organizationId,
      },
    })

    if (!server) {
      return NextResponse.json({ error: 'Server not found' }, { status: 404 })
    }

    // Get or create API key for this organization
    let apiKey = await prisma.apiKey.findFirst({
      where: {
        organizationId: organizationId,
        isActive: true,
      },
    })

    if (!apiKey) {
      // Generate a new API key
      const keyValue = `sm_${organizationId}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
      
      apiKey = await prisma.apiKey.create({
        data: {
          name: 'Default API Key',
          key: keyValue,
          organizationId: organizationId,
          isActive: true,
        },
      })
    }

    // Generate the install command based on OS type
    const installCommand = generateInstallCommand({
      serverName: server.name || server.hostId,
      serverIP: server.ipAddress || 'localhost',
      orgId: organizationId,
      apiKey: apiKey.key,
      osType: server.osInfo || 'linux',
      hostId: server.hostId,
    })

    return NextResponse.json({ 
      command: installCommand,
      serverName: server.name || server.hostId,
      osType: server.osInfo || 'linux',
      ipAddress: server.ipAddress || 'localhost'
    })
  } catch (error) {
    console.error('Error generating install script:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

function generateInstallCommand(config: {
  serverName: string
  serverIP: string
  orgId: string
  apiKey: string
  osType: string
  hostId: string
}) {
  const { apiKey, osType } = config
  
  // Use the existing GitHub install script
  const baseUrl = 'https://raw.githubusercontent.com/mulutu/security-manager/main/installer'
  
  if (osType === 'windows') {
    // For Windows, you might need a PowerShell script - using placeholder for now
    return `# Windows installer not yet available - please use Linux/WSL
# Set token and run installer
# $env:SM_TOKEN="${apiKey}"; curl -fsSL "${baseUrl}/install.ps1" | powershell`
  } else {
    // For Linux and macOS, pass only token as argument to bash
    // This is much cleaner - the agent extracts everything from the token
    return `curl -fsSL ${baseUrl}/install.sh | sudo bash -s SM_TOKEN="${apiKey}"`
  }
} 