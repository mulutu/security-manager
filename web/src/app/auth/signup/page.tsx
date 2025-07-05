import { Metadata } from 'next'
import Link from 'next/link'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Shield } from 'lucide-react'
import { GoogleSignInButton } from '@/components/auth/GoogleSignInButton'

export const metadata: Metadata = {
  title: 'Sign Up | Security Manager',
  description: 'Create your Security Manager account',
}

export default function SignUpPage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 to-slate-100 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        {/* Header */}
        <div className="text-center mb-8">
          <Link href="/" className="inline-flex items-center space-x-2 mb-4">
            <Shield className="h-8 w-8 text-blue-600" />
            <span className="text-2xl font-bold text-slate-900">Security Manager</span>
          </Link>
          <h1 className="text-3xl font-bold text-slate-900 mb-2">Get started</h1>
          <p className="text-slate-600">Create your account to start monitoring</p>
        </div>

        {/* Sign Up Card */}
        <Card>
          <CardHeader className="text-center">
            <CardTitle>Create Account</CardTitle>
            <CardDescription>
              Sign up with your Google account to get started
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <GoogleSignInButton />
            
            <div className="text-center">
              <p className="text-sm text-slate-600">
                Already have an account?{' '}
                <Link href="/auth/signin" className="text-blue-600 hover:underline">
                  Sign in
                </Link>
              </p>
            </div>
          </CardContent>
        </Card>

        {/* Features Preview */}
        <div className="mt-8 text-center">
          <p className="text-sm text-slate-500 mb-4">What you&apos;ll get:</p>
          <div className="grid grid-cols-1 gap-2 text-sm text-slate-600">
            <div className="flex items-center justify-center space-x-2">
              <div className="w-2 h-2 bg-green-500 rounded-full"></div>
              <span>Free tier with 5 agents</span>
            </div>
            <div className="flex items-center justify-center space-x-2">
              <div className="w-2 h-2 bg-green-500 rounded-full"></div>
              <span>Real-time security monitoring</span>
            </div>
            <div className="flex items-center justify-center space-x-2">
              <div className="w-2 h-2 bg-green-500 rounded-full"></div>
              <span>Automated threat response</span>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="text-center mt-8">
          <p className="text-sm text-slate-500">
            By signing up, you agree to our{' '}
            <Link href="/terms" className="text-blue-600 hover:underline">
              Terms of Service
            </Link>{' '}
            and{' '}
            <Link href="/privacy" className="text-blue-600 hover:underline">
              Privacy Policy
            </Link>
          </p>
        </div>
      </div>
    </div>
  )
} 