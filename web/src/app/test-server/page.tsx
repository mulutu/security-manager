"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"

export default function TestServerPage() {
  const [result, setResult] = useState("")

  const testAPI = async () => {
    try {
      const response = await fetch('/api/servers')
      const data = await response.json()
      setResult(JSON.stringify(data, null, 2))
    } catch (error) {
      setResult(`Error: ${error}`)
    }
  }

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold mb-4">Server API Test</h1>
      <Button onClick={testAPI} className="mb-4">
        Test Server API
      </Button>
      <pre className="bg-gray-100 p-4 rounded">
        {result || "Click the button to test the API"}
      </pre>
    </div>
  )
} 