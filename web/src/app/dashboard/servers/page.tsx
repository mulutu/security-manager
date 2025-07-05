"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Badge } from "@/components/ui/badge"
import { Copy, Server, Plus, Download, CheckCircle, XCircle, Clock, AlertCircle, Trash2, RefreshCw } from "lucide-react"
import { useToast } from "@/hooks/use-toast"
import { Label } from "@/components/ui/label"

interface Server {
  id: string
  name: string
  ipAddress: string
  osType: string
  status: 'online' | 'offline' | 'pending'
  lastSeen?: Date
  agentVersion?: string
  organizationId: string
  createdAt: Date
}

export default function ServersPage() {
  const [servers, setServers] = useState<Server[]>([])
  const [loading, setLoading] = useState(true)
  const [installCommand, setInstallCommand] = useState("")
  const [generatingCommand, setGeneratingCommand] = useState(false)
  const [needsOrganization, setNeedsOrganization] = useState(false)
  const [settingUpOrg, setSettingUpOrg] = useState(false)
  const [deletingServer, setDeletingServer] = useState<string | null>(null)
  const [activeTab, setActiveTab] = useState("servers")
  const { toast } = useToast()

  useEffect(() => {
    fetchServers()
  }, [])

  const fetchServers = async () => {
    try {
      const response = await fetch('/api/servers')
      if (response.ok) {
        const data = await response.json()
        setServers(data)
        setNeedsOrganization(false)
      } else if (response.status === 403) {
        // User needs organization setup
        setNeedsOrganization(true)
      } else {
        throw new Error('Failed to fetch servers')
      }
    } catch {
      console.error('Error fetching servers')
    } finally {
      setLoading(false)
    }
  }

  const setupOrganization = async () => {
    setSettingUpOrg(true)
    try {
      const response = await fetch('/api/setup-organization', {
        method: 'POST',
      })
      
      if (response.ok) {
        toast({
          title: "Organization setup complete",
          description: "Your organization has been created successfully.",
        })
        // Refresh servers after organization is created
        await fetchServers()
      } else {
        throw new Error('Failed to setup organization')
      }
    } catch {
      toast({
        title: "Error setting up organization",
        description: "Please try again later.",
        variant: "destructive",
      })
    } finally {
      setSettingUpOrg(false)
    }
  }

  const generateNewServerCommand = async () => {
    setGeneratingCommand(true)
    try {
      const response = await fetch('/api/servers/generate-install-command', {
        method: 'POST',
      })
      
      if (response.ok) {
        const data = await response.json()
        setInstallCommand(data.command)
        setActiveTab("install") // Switch to install tab
        toast({
          title: "Install command generated",
          description: "Copy and run the command on your server to add it to monitoring.",
        })
      } else if (response.status === 403) {
        setNeedsOrganization(true)
      } else {
        throw new Error('Failed to generate install command')
      }
    } catch {
      toast({
        title: "Error generating command",
        description: "Please try again later.",
        variant: "destructive",
      })
    } finally {
      setGeneratingCommand(false)
    }
  }

  const handleDeleteServer = async (serverId: string) => {
    setDeletingServer(serverId)
    
    try {
      const response = await fetch(`/api/servers/${serverId}`, {
        method: 'DELETE',
      })

      if (response.ok) {
        setServers(servers.filter(s => s.id !== serverId))
        toast({
          title: "Server deleted successfully",
          description: "The server has been removed from your organization.",
        })
      } else {
        throw new Error('Failed to delete server')
      }
    } catch {
      toast({
        title: "Error deleting server",
        description: "Please try again later.",
        variant: "destructive",
      })
    } finally {
      setDeletingServer(null)
    }
  }

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text)
    toast({
      title: "Copied to clipboard",
      description: "Install command copied successfully.",
    })
  }

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'online':
        return <CheckCircle className="h-4 w-4 text-green-500" />
      case 'offline':
        return <XCircle className="h-4 w-4 text-red-500" />
      default:
        return <Clock className="h-4 w-4 text-yellow-500" />
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'online':
        return 'bg-green-100 text-green-800'
      case 'offline':
        return 'bg-red-100 text-red-800'
      default:
        return 'bg-yellow-100 text-yellow-800'
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-slate-600">Loading servers...</p>
        </div>
      </div>
    )
  }

  // Show organization setup if needed
  if (needsOrganization) {
    return (
      <div className="min-h-screen bg-slate-50">
        <div className="container mx-auto px-4 py-8">
          <div className="max-w-md mx-auto">
            <Card>
              <CardHeader>
                <div className="flex items-center gap-2">
                  <AlertCircle className="h-5 w-5 text-blue-600" />
                  <CardTitle>Organization Setup Required</CardTitle>
                </div>
                <CardDescription>
                  You need to set up an organization before you can manage servers.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  <p className="text-sm text-slate-600">
                    We&apos;ll create a default organization for you to get started with server monitoring.
                  </p>
                  <Button 
                    onClick={setupOrganization} 
                    disabled={settingUpOrg}
                    className="w-full"
                  >
                    {settingUpOrg ? "Setting up..." : "Set Up Organization"}
                  </Button>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-slate-50">
      <div className="container mx-auto px-4 py-8">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-slate-900 mb-2">Server Management</h1>
          <p className="text-slate-600">Add and manage your servers for security monitoring</p>
        </div>

        <Tabs value={activeTab} onValueChange={setActiveTab} className="space-y-6">
          <TabsList>
            <TabsTrigger value="servers">Your Servers</TabsTrigger>
            {installCommand && <TabsTrigger value="install">Install Script</TabsTrigger>}
          </TabsList>

          <TabsContent value="servers" className="space-y-6">
            <Card>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <div>
                    <CardTitle className="flex items-center gap-2">
                      <Server className="h-5 w-5" />
                      Configured Servers
                    </CardTitle>
                    <CardDescription>
                      Servers configured for security monitoring
                    </CardDescription>
                  </div>
                  <div className="flex items-center gap-2">
                    <Button 
                      variant="outline" 
                      onClick={fetchServers}
                      disabled={loading}
                    >
                      <RefreshCw className={`h-4 w-4 mr-1 ${loading ? 'animate-spin' : ''}`} />
                      Refresh
                    </Button>
                    <Button 
                      onClick={generateNewServerCommand} 
                      disabled={generatingCommand}
                      className="flex items-center gap-2"
                    >
                      {generatingCommand ? (
                        <div className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
                      ) : (
                        <Plus className="h-4 w-4" />
                      )}
                      Add Server
                    </Button>
                  </div>
                </div>
              </CardHeader>
              <CardContent>
                {servers.length === 0 ? (
                  <div className="text-center py-12">
                    <Server className="h-16 w-16 text-slate-300 mx-auto mb-4" />
                    <h3 className="text-lg font-semibold text-slate-900 mb-2">No servers configured</h3>
                    <p className="text-slate-600 mb-4">Generate an install script to add your first server</p>
                    <Button 
                      onClick={generateNewServerCommand} 
                      disabled={generatingCommand}
                      className="flex items-center gap-2"
                    >
                      {generatingCommand ? (
                        <div className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
                      ) : (
                        <Plus className="h-4 w-4" />
                      )}
                      Generate Install Script
                    </Button>
                  </div>
                ) : (
                  <div className="grid gap-4">
                    {servers.map((server) => (
                      <Card key={server.id} className="p-4">
                        <div className="flex items-center justify-between">
                          <div className="flex items-center gap-4">
                            <div className="flex items-center gap-2">
                              {getStatusIcon(server.status)}
                              <div>
                                <h3 className="font-semibold text-slate-900">{server.name}</h3>
                                <p className="text-sm text-slate-600">{server.ipAddress}</p>
                              </div>
                            </div>
                            <Badge className={getStatusColor(server.status)}>
                              {server.status}
                            </Badge>
                            <Badge variant="outline">
                              {server.osType}
                            </Badge>
                            {server.agentVersion && (
                              <Badge variant="outline">
                                v{server.agentVersion}
                              </Badge>
                            )}
                          </div>
                          <div className="flex items-center gap-2">
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => handleDeleteServer(server.id)}
                              disabled={deletingServer === server.id}
                              className="text-red-600 hover:text-red-700 hover:bg-red-50"
                            >
                              {deletingServer === server.id ? (
                                <div className="h-4 w-4 animate-spin rounded-full border-2 border-red-600 border-t-transparent mr-1" />
                              ) : (
                                <Trash2 className="h-4 w-4 mr-1" />
                              )}
                              Remove
                            </Button>
                          </div>
                        </div>
                      </Card>
                    ))}
                  </div>
                )}
              </CardContent>
            </Card>
          </TabsContent>

          {installCommand && (
            <TabsContent value="install" className="space-y-6">
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <Download className="h-5 w-5" />
                    Add New Server to Security Manager
                  </CardTitle>
                  <CardDescription>
                    Run this command on any server to automatically add it to your monitoring dashboard
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-6">
                    <div className="space-y-4">
                      <div>
                        <Label className="text-sm font-medium text-slate-700 mb-2 block">
                          One-line installer command - copy and run on your server:
                        </Label>
                        <div className="relative bg-slate-900 text-green-400 p-4 rounded-lg font-mono text-sm">
                          <code className="break-all">{installCommand}</code>
                          <Button
                            size="sm"
                            variant="outline"
                            className="absolute top-2 right-2 bg-slate-800 border-slate-600 text-white hover:bg-slate-700"
                            onClick={() => copyToClipboard(installCommand)}
                          >
                            <Copy className="h-4 w-4 mr-1" />
                            Copy
                          </Button>
                        </div>
                      </div>
                      
                      <div className="bg-blue-50 p-4 rounded-lg border border-blue-200">
                        <h4 className="font-semibold text-blue-900 mb-3 flex items-center gap-2">
                          <AlertCircle className="h-4 w-4" />
                          Simple Installation Process:
                        </h4>
                        <ol className="text-sm text-blue-800 space-y-2">
                          <li className="flex items-start gap-2">
                            <span className="bg-blue-200 text-blue-900 rounded-full w-5 h-5 flex items-center justify-center text-xs font-bold mt-0.5">1</span>
                            <span>Copy the one-line command above</span>
                          </li>
                          <li className="flex items-start gap-2">
                            <span className="bg-blue-200 text-blue-900 rounded-full w-5 h-5 flex items-center justify-center text-xs font-bold mt-0.5">2</span>
                            <span>SSH into your server as root or with sudo access</span>
                          </li>
                          <li className="flex items-start gap-2">
                            <span className="bg-blue-200 text-blue-900 rounded-full w-5 h-5 flex items-center justify-center text-xs font-bold mt-0.5">3</span>
                            <span>Paste and run the command</span>
                          </li>
                          <li className="flex items-start gap-2">
                            <span className="bg-blue-200 text-blue-900 rounded-full w-5 h-5 flex items-center justify-center text-xs font-bold mt-0.5">4</span>
                            <span>The server will automatically appear in your dashboard within seconds</span>
                          </li>
                        </ol>
                        
                        <div className="mt-3 p-3 bg-blue-100 rounded border-l-4 border-blue-400">
                          <p className="text-xs text-blue-700">
                            <strong>🔒 Secure & Automatic:</strong> The agent will automatically register itself with its hostname and IP address. No manual configuration needed!
                          </p>
                        </div>
                      </div>
                      
                      <div className="bg-green-50 p-4 rounded-lg border border-green-200">
                        <h4 className="font-semibold text-green-900 mb-2">🚀 What happens after installation?</h4>
                        <ul className="text-sm text-green-800 space-y-1">
                          <li>• Agent automatically detects server hostname and OS</li>
                          <li>• Server appears in your dashboard within 30 seconds</li>
                          <li>• Real-time security monitoring begins immediately</li>
                          <li>• No IP addresses stored - enhanced security</li>
                          <li>• Agent self-registers with your organization</li>
                        </ul>
                      </div>

                      <div className="flex gap-2">
                        <Button 
                          onClick={generateNewServerCommand} 
                          disabled={generatingCommand}
                          variant="outline"
                        >
                          {generatingCommand ? (
                            <div className="h-4 w-4 animate-spin rounded-full border-2 border-slate-600 border-t-transparent mr-1" />
                          ) : (
                            <RefreshCw className="h-4 w-4 mr-1" />
                          )}
                          Generate New Command
                        </Button>
                        <Button 
                          onClick={() => setActiveTab("servers")}
                          variant="outline"
                        >
                          Back to Servers
                        </Button>
                      </div>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </TabsContent>
          )}
        </Tabs>
      </div>
    </div>
  )
} 