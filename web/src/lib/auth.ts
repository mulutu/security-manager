import GoogleProvider from "next-auth/providers/google"
import { PrismaAdapter } from "@auth/prisma-adapter"
import { prisma } from "./prisma"

export const authOptions = {
  adapter: PrismaAdapter(prisma),
  providers: [
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
    }),
  ],
  callbacks: {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    async session({ session, user }: any) {
      if (session.user && user) {
        session.user.id = user.id
        
        // Get user's organization
        const userWithOrg = await prisma.user.findUnique({
          where: { id: user.id },
          include: { organization: true }
        })
        
        // If user doesn't have an organization, create one
        if (userWithOrg && !userWithOrg.organization) {
          try {
            const orgName = `${session.user.name || 'User'}'s Organization`
            const baseSlug = orgName.toLowerCase()
              .replace(/[^a-z0-9]+/g, '-')
              .replace(/^-+|-+$/g, '')
            const uniqueSlug = `${baseSlug}-${Date.now()}`
            
            console.log('Creating organization during session callback:', uniqueSlug)
            
            const organization = await prisma.organization.create({
              data: {
                name: orgName,
                slug: uniqueSlug,
                plan: "FREE",
                maxAgents: 5,
              }
            })

            await prisma.user.update({
              where: { id: user.id },
              data: { organizationId: organization.id }
            })
            
            console.log('Organization created in session callback:', organization.id)
            
            session.user.organizationId = organization.id
            session.user.organizationName = organization.name
          } catch (error) {
            console.error('Error creating organization in session callback:', error)
          }
        } else if (userWithOrg?.organization) {
          session.user.organizationId = userWithOrg.organization.id
          session.user.organizationName = userWithOrg.organization.name
        }
      }
      return session
    },
  },
  pages: {
    signIn: "/auth/signin",
    error: "/auth/error",
  },
  session: {
    strategy: "database" as const,
  },
} 