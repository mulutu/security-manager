"use client"

import { useState, useEffect } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Badge } from "@/components/ui/badge"
import { Copy, Server, Plus, Download, CheckCircle, XCircle, Clock, AlertCircle, Edit, Trash2 } from "lucide-react"
import { useToast } from "@/hooks/use-toast"

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
  const [selectedServer, setSelectedServer] = useState<Server | null>(null)
  const [needsOrganization, setNeedsOrganization] = useState(false)
  const [settingUpOrg, setSettingUpOrg] = useState(false)
  const [editingServer, setEditingServer] = useState<Server | null>(null)
  const [deletingServer, setDeletingServer] = useState<string | null>(null)
  const [activeTab, setActiveTab] = useState("servers")
  const { toast } = useToast()

  // Form state
  const [formData, setFormData] = useState({
    name: "",
    ipAddress: "",
    osType: "linux"
  })

  // Edit form state
  const [editFormData, setEditFormData] = useState({
    name: "",
    ipAddress: "",
    osType: "linux"
  })

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

  const handleAddServer = async (e: React.FormEvent) => {
    e.preventDefault()
    
    try {
      const response = await fetch('/api/servers', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(formData),
      })

      if (response.ok) {
        const newServer = await response.json()
        setServers([...servers, newServer])
        setFormData({ name: "", ipAddress: "", osType: "linux" })
        setActiveTab("servers") // Switch back to servers tab
        toast({
          title: "Server added successfully",
          description: `${newServer.name} has been added to your organization.`,
        })
      } else if (response.status === 403) {
        // User needs organization setup
        setNeedsOrganization(true)
      } else {
        throw new Error('Failed to add server')
      }
    } catch {
      toast({
        title: "Error adding server",
        description: "Please try again later.",
        variant: "destructive",
      })
    }
  }

  const handleEditServer = async (e: React.FormEvent) => {
    e.preventDefault()
    
    if (!editingServer) return

    try {
      const response = await fetch(`/api/servers/${editingServer.id}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(editFormData),
      })

      if (response.ok) {
        const updatedServer = await response.json()
        setServers(servers.map(s => s.id === editingServer.id ? updatedServer : s))
        setEditingServer(null)
        setEditFormData({ name: "", ipAddress: "", osType: "linux" })
        toast({
          title: "Server updated successfully",
          description: `${updatedServer.name} has been updated.`,
        })
      } else {
        throw new Error('Failed to update server')
      }
    } catch {
      toast({
        title: "Error updating server",
        description: "Please try again later.",
        variant: "destructive",
      })
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

  const startEditServer = (server: Server) => {
    setEditingServer(server)
    setEditFormData({
      name: server.name,
      ipAddress: server.ipAddress,
      osType: server.osType
    })
  }

  const cancelEdit = () => {
    setEditingServer(null)
    setEditFormData({ name: "", ipAddress: "", osType: "linux" })
  }

  const generateInstallCommand = async (server: Server) => {
    try {
      const response = await fetch(`/api/servers/${server.id}/install-script`)
      if (response.ok) {
        const data = await response.json()
        setInstallCommand(data.command)
        setSelectedServer(server)
        setActiveTab("install") // Switch to install tab
      }
    } catch {
      toast({
        title: "Error generating command",
        description: "Please try again later.",
        variant: "destructive",
      })
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
            <TabsTrigger value="add">Add Server</TabsTrigger>
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
                  <Button onClick={() => setActiveTab("add")} className="flex items-center gap-2">
                    <Plus className="h-4 w-4" />
                    Add Server
                  </Button>
                </div>
              </CardHeader>
              <CardContent>
                {servers.length === 0 ? (
                  <div className="text-center py-12">
                    <Server className="h-16 w-16 text-slate-300 mx-auto mb-4" />
                    <h3 className="text-lg font-semibold text-slate-900 mb-2">No servers configured</h3>
                    <p className="text-slate-600 mb-4">Add your first server to start monitoring</p>
                    <Button onClick={() => setActiveTab("add")} className="flex items-center gap-2">
                      <Plus className="h-4 w-4" />
                      Add Your First Server
                    </Button>
                  </div>
                ) : (
                  <div className="grid gap-4">
                    {servers.map((server) => (
                      <Card key={server.id} className="p-4">
                        {editingServer?.id === server.id ? (
                          // Edit form
                          <form onSubmit={handleEditServer} className="space-y-4">
                            <div className="grid grid-cols-2 gap-4">
                              <div className="space-y-2">
                                <Label htmlFor={`edit-name-${server.id}`}>Server Name</Label>
                                <Input
                                  id={`edit-name-${server.id}`}
                                  value={editFormData.name}
                                  onChange={(e) => setEditFormData({ ...editFormData, name: e.target.value })}
                                  required
                                />
                              </div>
                              <div className="space-y-2">
                                <Label htmlFor={`edit-ip-${server.id}`}>IP Address</Label>
                                <Input
                                  id={`edit-ip-${server.id}`}
                                  value={editFormData.ipAddress}
                                  onChange={(e) => setEditFormData({ ...editFormData, ipAddress: e.target.value })}
                                  required
                                />
                              </div>
                            </div>
                            <div className="space-y-2">
                              <Label htmlFor={`edit-os-${server.id}`}>Operating System</Label>
                              <Select value={editFormData.osType} onValueChange={(value) => setEditFormData({ ...editFormData, osType: value })}>
                                <SelectTrigger>
                                  <SelectValue placeholder="Select OS type" />
                                </SelectTrigger>
                                <SelectContent>
                                  <SelectItem value="linux">Linux</SelectItem>
                                  <SelectItem value="windows">Windows</SelectItem>
                                  <SelectItem value="macos">macOS</SelectItem>
                                </SelectContent>
                              </Select>
                            </div>
                            <div className="flex gap-2">
                              <Button type="submit" size="sm">
                                Save Changes
                              </Button>
                              <Button type="button" variant="outline" size="sm" onClick={cancelEdit}>
                                Cancel
                              </Button>
                            </div>
                          </form>
                        ) : (
                          // Display server info
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
                            </div>
                            <div className="flex items-center gap-2">
                              <Button
                                variant="outline"
                                size="sm"
                                onClick={() => generateInstallCommand(server)}
                              >
                                <Download className="h-4 w-4 mr-1" />
                                Install Script
                              </Button>
                              <Button
                                variant="outline"
                                size="sm"
                                onClick={() => startEditServer(server)}
                              >
                                <Edit className="h-4 w-4 mr-1" />
                                Edit
                              </Button>
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
                                Delete
                              </Button>
                            </div>
                          </div>
                        )}
                      </Card>
                    ))}
                  </div>
                )}
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="add" className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle>Add New Server</CardTitle>
                <CardDescription>
                  Configure a new server for security monitoring
                </CardDescription>
              </CardHeader>
              <CardContent>
                <form onSubmit={handleAddServer} className="space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div className="space-y-2">
                      <Label htmlFor="name">Server Name</Label>
                      <Input
                        id="name"
                        value={formData.name}
                        onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                        placeholder="e.g., Production Web Server"
                        required
                      />
                    </div>
                    <div className="space-y-2">
                      <Label htmlFor="ipAddress">IP Address</Label>
                      <Input
                        id="ipAddress"
                        value={formData.ipAddress}
                        onChange={(e) => setFormData({ ...formData, ipAddress: e.target.value })}
                        placeholder="e.g., 192.168.1.100"
                        required
                      />
                    </div>
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="osType">Operating System</Label>
                    <Select value={formData.osType} onValueChange={(value) => setFormData({ ...formData, osType: value })}>
                      <SelectTrigger>
                        <SelectValue placeholder="Select OS type" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="linux">Linux</SelectItem>
                        <SelectItem value="windows">Windows</SelectItem>
                        <SelectItem value="macos">macOS</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div className="flex gap-2">
                    <Button type="submit" className="flex-1">
                      Add Server
                    </Button>
                    <Button type="button" variant="outline" onClick={() => setActiveTab("servers")}>
                      Cancel
                    </Button>
                  </div>
                </form>
              </CardContent>
            </Card>
          </TabsContent>

          {installCommand && (
            <TabsContent value="install" className="space-y-6">
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <Download className="h-5 w-5" />
                    Install Security Manager Agent on {selectedServer?.name}
                  </CardTitle>
                  <CardDescription>
                    One simple command installs and configures the agent automatically
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-6">
                    <div className="flex items-center gap-2">
                      <Badge variant="outline">
                        {selectedServer?.osType}
                      </Badge>
                      <Badge variant="outline">
                        {selectedServer?.ipAddress}
                      </Badge>
                    </div>
                    
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
                          Quick Installation:
                        </h4>
                        <ol className="text-sm text-blue-800 space-y-2">
                          <li className="flex items-start gap-2">
                            <span className="bg-blue-200 text-blue-900 rounded-full w-5 h-5 flex items-center justify-center text-xs font-bold mt-0.5">1</span>
                            <span>Copy the one-line command above</span>
                          </li>
                          <li className="flex items-start gap-2">
                            <span className="bg-blue-200 text-blue-900 rounded-full w-5 h-5 flex items-center justify-center text-xs font-bold mt-0.5">2</span>
                            <span>SSH into your server: <code className="bg-blue-100 px-1 rounded">ssh root@{selectedServer?.ipAddress}</code></span>
                          </li>
                          <li className="flex items-start gap-2">
                            <span className="bg-blue-200 text-blue-900 rounded-full w-5 h-5 flex items-center justify-center text-xs font-bold mt-0.5">3</span>
                            <span>Paste and run the command (requires sudo/root access)</span>
                          </li>
                          <li className="flex items-start gap-2">
                            <span className="bg-blue-200 text-blue-900 rounded-full w-5 h-5 flex items-center justify-center text-xs font-bold mt-0.5">4</span>
                            <span>Agent installs automatically and connects to your dashboard</span>
                          </li>
                        </ol>
                        
                        <div className="mt-3 p-3 bg-blue-100 rounded border-l-4 border-blue-400">
                          <p className="text-xs text-blue-700">
                            <strong>Secure:</strong> The command contains your unique organization token and automatically configures the agent for your account. No manual setup required!
                          </p>
                        </div>
                      </div>
                      
                      <div className="bg-green-50 p-4 rounded-lg border border-green-200">
                        <h4 className="font-semibold text-green-900 mb-2">🚀 What happens after installation?</h4>
                        <ul className="text-sm text-green-800 space-y-1">
                          <li>• Agent connects automatically to Security Manager</li>
                          <li>• Server status updates to &quot;Online&quot; in this dashboard</li>
                          <li>• Real-time security monitoring begins immediately</li>
                          <li>• You&apos;ll receive instant alerts for security events</li>
                          <li>• No additional configuration needed</li>
                        </ul>
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