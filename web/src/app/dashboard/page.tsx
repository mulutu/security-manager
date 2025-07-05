import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Shield, AlertTriangle, Activity, Server, Eye, Plus, Settings } from 'lucide-react'
import Link from 'next/link'

export default function DashboardPage() {
  return (
    <div className="min-h-screen bg-slate-50">
      {/* Header */}
      <header className="bg-white border-b">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <Shield className="h-8 w-8 text-blue-600" />
              <div>
                <h1 className="text-xl font-bold">Security Manager</h1>
                <p className="text-sm text-slate-600">Dashboard</p>
              </div>
            </div>
            <div className="flex items-center space-x-4">
              <Badge variant="outline" className="bg-green-50 text-green-700 border-green-200">
                <div className="w-2 h-2 bg-green-500 rounded-full mr-2"></div>
                All Systems Operational
              </Badge>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="container mx-auto px-4 py-8">
        {/* Overview Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Active Agents</CardTitle>
              <Server className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">12</div>
              <p className="text-xs text-muted-foreground">
                +2 from last week
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Security Alerts</CardTitle>
              <AlertTriangle className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-orange-600">3</div>
              <p className="text-xs text-muted-foreground">
                2 high severity
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Events Today</CardTitle>
              <Activity className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">1,247</div>
              <p className="text-xs text-muted-foreground">
                +12% from yesterday
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium">Mitigations</CardTitle>
              <Shield className="h-4 w-4 text-muted-foreground" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-green-600">8</div>
              <p className="text-xs text-muted-foreground">
                100% success rate
              </p>
            </CardContent>
          </Card>
        </div>

        {/* Main Dashboard */}
        <Tabs defaultValue="overview" className="space-y-6">
          <TabsList>
            <TabsTrigger value="overview">Overview</TabsTrigger>
            <TabsTrigger value="alerts">Alerts</TabsTrigger>
            <TabsTrigger value="agents">Agents</TabsTrigger>
            <TabsTrigger value="events">Events</TabsTrigger>
          </TabsList>

          <TabsContent value="overview" className="space-y-6">
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* Recent Alerts */}
              <Card>
                <CardHeader>
                  <CardTitle>Recent Alerts</CardTitle>
                  <CardDescription>
                    Latest security alerts from your infrastructure
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-4">
                    <div className="flex items-center justify-between p-3 bg-red-50 border border-red-200 rounded-lg">
                      <div className="flex items-center space-x-3">
                        <AlertTriangle className="h-5 w-5 text-red-600" />
                        <div>
                          <p className="font-medium text-red-900">SSH Brute Force Detected</p>
                          <p className="text-sm text-red-700">server-01 • 2 minutes ago</p>
                        </div>
                      </div>
                      <Badge variant="destructive">High</Badge>
                    </div>

                    <div className="flex items-center justify-between p-3 bg-orange-50 border border-orange-200 rounded-lg">
                      <div className="flex items-center space-x-3">
                        <Activity className="h-5 w-5 text-orange-600" />
                        <div>
                          <p className="font-medium text-orange-900">High CPU Usage</p>
                          <p className="text-sm text-orange-700">server-03 • 15 minutes ago</p>
                        </div>
                      </div>
                      <Badge variant="secondary">Medium</Badge>
                    </div>

                    <div className="flex items-center justify-between p-3 bg-yellow-50 border border-yellow-200 rounded-lg">
                      <div className="flex items-center space-x-3">
                        <Eye className="h-5 w-5 text-yellow-600" />
                        <div>
                          <p className="font-medium text-yellow-900">Suspicious Process</p>
                          <p className="text-sm text-yellow-700">server-02 • 1 hour ago</p>
                        </div>
                      </div>
                      <Badge variant="outline">Low</Badge>
                    </div>
                  </div>
                </CardContent>
              </Card>

              {/* Agent Status */}
              <Card>
                <CardHeader>
                  <CardTitle>Agent Status</CardTitle>
                  <CardDescription>
                    Health status of your security agents
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-3">
                    <div className="flex items-center justify-between p-3 bg-green-50 border border-green-200 rounded-lg">
                      <div className="flex items-center space-x-3">
                        <div className="w-3 h-3 bg-green-500 rounded-full"></div>
                        <div>
                          <p className="font-medium">server-01</p>
                          <p className="text-sm text-slate-600">Online • 2 minutes ago</p>
                        </div>
                      </div>
                      <Badge variant="outline" className="bg-green-50 text-green-700">Online</Badge>
                    </div>

                    <div className="flex items-center justify-between p-3 bg-green-50 border border-green-200 rounded-lg">
                      <div className="flex items-center space-x-3">
                        <div className="w-3 h-3 bg-green-500 rounded-full"></div>
                        <div>
                          <p className="font-medium">server-02</p>
                          <p className="text-sm text-slate-600">Online • 5 minutes ago</p>
                        </div>
                      </div>
                      <Badge variant="outline" className="bg-green-50 text-green-700">Online</Badge>
                    </div>

                    <div className="flex items-center justify-between p-3 bg-green-50 border border-green-200 rounded-lg">
                      <div className="flex items-center space-x-3">
                        <div className="w-3 h-3 bg-green-500 rounded-full"></div>
                        <div>
                          <p className="font-medium">server-03</p>
                          <p className="text-sm text-slate-600">Online • 1 minute ago</p>
                        </div>
                      </div>
                      <Badge variant="outline" className="bg-green-50 text-green-700">Online</Badge>
                    </div>

                    <div className="flex items-center justify-between p-3 bg-red-50 border border-red-200 rounded-lg">
                      <div className="flex items-center space-x-3">
                        <div className="w-3 h-3 bg-red-500 rounded-full"></div>
                        <div>
                          <p className="font-medium">server-04</p>
                          <p className="text-sm text-slate-600">Offline • 2 hours ago</p>
                        </div>
                      </div>
                      <Badge variant="destructive">Offline</Badge>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </div>

            {/* System Metrics */}
            <Card>
              <CardHeader>
                <CardTitle>System Performance</CardTitle>
                <CardDescription>
                  Real-time metrics across your infrastructure
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                  <div className="text-center">
                    <div className="text-3xl font-bold text-blue-600">23.4%</div>
                    <p className="text-sm text-slate-600">Average CPU</p>
                  </div>
                  <div className="text-center">
                    <div className="text-3xl font-bold text-green-600">45.2%</div>
                    <p className="text-sm text-slate-600">Average Memory</p>
                  </div>
                  <div className="text-center">
                    <div className="text-3xl font-bold text-orange-600">67.8%</div>
                    <p className="text-sm text-slate-600">Average Disk</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="alerts" className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle>Security Alerts</CardTitle>
                <CardDescription>
                  All active and resolved security alerts
                </CardDescription>
              </CardHeader>
              <CardContent>
                <p className="text-slate-600">Alert management interface coming soon...</p>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="agents" className="space-y-6">
            <Card>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <div>
                    <CardTitle className="flex items-center gap-2">
                      <Server className="h-5 w-5" />
                      Agent Management
                    </CardTitle>
                    <CardDescription>
                      Manage and monitor your security agents
                    </CardDescription>
                  </div>
                  <div className="flex gap-2">
                    <Link href="/dashboard/servers">
                      <Button className="flex items-center gap-2">
                        <Plus className="h-4 w-4" />
                        Add Server
                      </Button>
                    </Link>
                    <Link href="/dashboard/servers">
                      <Button variant="outline" className="flex items-center gap-2">
                        <Settings className="h-4 w-4" />
                        Server Setup
                      </Button>
                    </Link>
                  </div>
                </div>
              </CardHeader>
              <CardContent>
                <div className="text-center py-12">
                  <Server className="h-16 w-16 text-slate-300 mx-auto mb-4" />
                  <h3 className="text-lg font-semibold text-slate-900 mb-2">Set up your first server</h3>
                  <p className="text-slate-600 mb-6">
                    Add servers to your organization and install monitoring agents to start collecting security data.
                  </p>
                  <div className="flex justify-center gap-4">
                    <Link href="/dashboard/servers">
                      <Button className="flex items-center gap-2">
                        <Plus className="h-4 w-4" />
                        Add Your First Server
                      </Button>
                    </Link>
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="events" className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle>Security Events</CardTitle>
                <CardDescription>
                  Real-time security event stream
                </CardDescription>
              </CardHeader>
              <CardContent>
                <p className="text-slate-600">Event stream interface coming soon...</p>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </main>
    </div>
  )
} 