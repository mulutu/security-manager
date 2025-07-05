import { NextResponse } from 'next/server'
import { getServerSession } from 'next-auth/next'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'

export async function POST() {
  try {
    const session = await getServerSession(authOptions)
    
    if (!session?.user?.id) {
      return NextResponse.json({ error: 'Not authenticated' }, { status: 401 })
    }

    // Check if user already has an organization
    const userWithOrg = await prisma.user.findUnique({
      where: { id: session.user.id },
      include: { organization: true }
    })

    if (userWithOrg?.organization) {
      return NextResponse.json({ 
        message: 'Organization already exists',
        organization: userWithOrg.organization 
      })
    }

    // Create organization for the user
    const orgName = `${session.user.name || 'User'}'s Organization`
    const baseSlug = orgName.toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
    const uniqueSlug = `${baseSlug}-${Date.now()}`
    
    console.log('Creating organization with slug:', uniqueSlug)
    
    const organization = await prisma.organization.create({
      data: {
        name: orgName,
        slug: uniqueSlug,
        plan: "FREE",
        maxAgents: 5,
      }
    })

    await prisma.user.update({
      where: { id: session.user.id },
      data: { organizationId: organization.id }
    })
    
    console.log('Organization created successfully:', organization.id)

    return NextResponse.json({ 
      message: 'Organization created successfully',
      organization: organization 
    })
  } catch (error) {
    console.error('Error setting up organization:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
} 