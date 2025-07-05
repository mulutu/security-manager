import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth/next'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const session = await getServerSession(authOptions)
    
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
      return NextResponse.json({ error: 'No organization found' }, { status: 403 })
    }

    // Check if server exists and belongs to the user's organization
    const server = await prisma.agent.findFirst({
      where: {
        id: id,
        organizationId: organizationId,
      },
    })

    if (!server) {
      return NextResponse.json({ error: 'Server not found' }, { status: 404 })
    }

    // Delete the server
    await prisma.agent.delete({
      where: { id: id }
    })

    return NextResponse.json({ message: 'Server deleted successfully' })
  } catch (error) {
    console.error('Error deleting server:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}

export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const session = await getServerSession(authOptions)
    
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
      return NextResponse.json({ error: 'No organization found' }, { status: 403 })
    }

    const body = await request.json()
    const { name, ipAddress, osType } = body

    // Validate input
    if (!name || !ipAddress || !osType) {
      return NextResponse.json({ error: 'Name, IP address, and OS type are required' }, { status: 400 })
    }

    // Check if server exists and belongs to the user's organization
    const server = await prisma.agent.findFirst({
      where: {
        id: id,
        organizationId: organizationId,
      },
    })

    if (!server) {
      return NextResponse.json({ error: 'Server not found' }, { status: 404 })
    }

    // Update the server
    const updatedServer = await prisma.agent.update({
      where: { id: id },
      data: {
        name,
        ipAddress,
        osInfo: osType,
        updatedAt: new Date(),
      },
    })

    return NextResponse.json(updatedServer)
  } catch (error) {
    console.error('Error updating server:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
} 