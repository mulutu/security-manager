import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth/next'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function POST() {
  try {
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
      return NextResponse.json({ error: 'No organization found. Please complete your setup.' }, { status: 403 })
    }

    // Get or create API key for this organization
    let apiKey = await prisma.apiKey.findFirst({
      where: {
        organizationId: organizationId,
        isActive: true,
      },
    })

    if (!apiKey) {
      // Create a new API key
      const keyValue = `sm_${organizationId}_${Date.now()}_${Math.random().toString(36).substring(2, 15)}`
      
      apiKey = await prisma.apiKey.create({
        data: {
          key: keyValue,
          organizationId: organizationId,
          name: 'Auto-generated agent key',
          isActive: true,
        }
      })
    }

    // Generate the install command
    const ingestUrl = process.env.INGEST_URL || '178.79.139.38:9002'
    const installCommand = `curl -fsSL https://raw.githubusercontent.com/mulutu/security-manager/main/installer/install.sh | sudo bash -s SM_TOKEN="${apiKey.key}"`

    return NextResponse.json({ 
      command: installCommand,
      token: apiKey.key.substring(0, 20) + '...', // Truncated for display
      ingestUrl 
    })
  } catch (error) {
    console.error('Error generating install command:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
} 