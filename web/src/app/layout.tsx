import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { Providers } from "@/components/providers/session-provider";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
});

export const metadata: Metadata = {
  title: "Security Manager - Enterprise Security Monitoring",
  description: "Protect your Linux infrastructure with automated threat detection and response. Deploy in minutes, monitor in real-time, sleep peacefully.",
  keywords: ["security", "monitoring", "linux", "threat detection", "automated response", "cybersecurity"],
  authors: [{ name: "Security Manager Team" }],
  creator: "Security Manager",
  publisher: "Security Manager",
  formatDetection: {
    email: false,
    address: false,
    telephone: false,
  },
  metadataBase: new URL(process.env.NEXTAUTH_URL || "http://localhost:3000"),
  openGraph: {
    title: "Security Manager - Enterprise Security Monitoring",
    description: "Protect your Linux infrastructure with automated threat detection and response.",
    url: "/",
    siteName: "Security Manager",
    locale: "en_US",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Security Manager - Enterprise Security Monitoring",
    description: "Protect your Linux infrastructure with automated threat detection and response.",
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-video-preview": -1,
      "max-image-preview": "large",
      "max-snippet": -1,
    },
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={inter.variable}>
      <body className="min-h-screen bg-background font-sans antialiased">
        <Providers>
          {children}
        </Providers>
      </body>
    </html>
  );
}
