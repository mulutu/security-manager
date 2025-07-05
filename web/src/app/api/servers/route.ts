import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth/next'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function GET() {
  try {
    const session = await getServerSession(authOptions)
    
    console.log('GET /api/servers - Session:', JSON.stringify(session, null, 2))
    
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

    const servers = await prisma.agent.findMany({
      where: {
        organizationId: organizationId,
      },
      orderBy: {
        createdAt: 'desc',
      },
    })

    // Transform the data to match the frontend interface
    const transformedServers = servers.map(server => ({
      id: server.id,
      name: server.name || server.hostId,
      ipAddress: server.ipAddress || 'Unknown',
      osType: server.osInfo || 'linux',
      status: server.status.toLowerCase(),
      lastSeen: server.lastSeen,
      agentVersion: server.version,
      organizationId: server.organizationId,
      createdAt: server.createdAt,
    }))

    return NextResponse.json(transformedServers)
  } catch (error) {
    console.error('Error fetching servers:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions)
    
    console.log('POST /api/servers - Session:', JSON.stringify(session, null, 2))
    
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

    const body = await request.json()
    const { name, ipAddress, osType } = body

    if (!name || !ipAddress || !osType) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })
    }

    // Check if server with this IP already exists for this organization
    const existingServer = await prisma.agent.findFirst({
      where: {
        organizationId: organizationId,
        ipAddress: ipAddress,
      },
    })

    if (existingServer) {
      return NextResponse.json({ error: 'Server with this IP address already exists' }, { status: 409 })
    }

    // Create new server/agent entry
    const newServer = await prisma.agent.create({
      data: {
        hostId: name.toLowerCase().replace(/\s+/g, '-'),
        name: name,
        ipAddress: ipAddress,
        osInfo: osType,
        organizationId: organizationId,
        status: 'OFFLINE', // Will be updated when agent connects
        capabilities: [], // Will be populated by agent
      },
    })

    // Transform the response to match frontend interface
    const transformedServer = {
      id: newServer.id,
      name: newServer.name,
      ipAddress: newServer.ipAddress,
      osType: newServer.osInfo,
      status: newServer.status.toLowerCase(),
      lastSeen: newServer.lastSeen,
      agentVersion: newServer.version,
      organizationId: newServer.organizationId,
      createdAt: newServer.createdAt,
    }

    return NextResponse.json(transformedServer, { status: 201 })
  } catch (error) {
    console.error('Error creating server:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
} 