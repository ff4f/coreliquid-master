import type React from "react"
import type { Metadata } from "next"
import { Inter } from "next/font/google"
import "./globals.css"
import "@rainbow-me/rainbowkit/styles.css"
import { ThemeProvider } from "@/components/theme-provider"
import Header from "@/components/header"

import { Web3Background } from "@/components/web3-background"

import { Providers } from "@/components/providers"

const inter = Inter({ 
  subsets: ["latin"],
  display: 'swap',
  fallback: ['system-ui', 'arial']
})

export const metadata: Metadata = {
  title: "CoreFluidX - Unified Liquidity Protocol",
  description: "Advanced DeFi protocol offering unified liquidity management, yield optimization, and cross-protocol integration on Core Chain.",
  keywords: ["DeFi", "Core Chain", "Liquidity Protocol", "Yield Farming", "Web3", "Cryptocurrency"],
  authors: [{ name: "CoreFluidX Team" }],
  creator: "CoreFluidX",
  publisher: "CoreFluidX",
  robots: "index, follow",
  openGraph: {
    title: "CoreFluidX - Unified Liquidity Protocol",
    description: "Advanced DeFi protocol offering unified liquidity management on Core Chain",
    type: "website",
    locale: "en_US",
  },
  twitter: {
    card: "summary_large_image",
    title: "CoreFluidX - Unified Liquidity Protocol",
    description: "Advanced DeFi protocol offering unified liquidity management on Core Chain",
  }
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={inter.className}>
        <Providers>
          <ThemeProvider attribute="class" defaultTheme="dark" enableSystem disableTransitionOnChange>
            <Web3Background />
             <div className="relative z-10 min-h-screen flex flex-col">
               <Header />
               <main className="flex-1 p-4 md:p-6 lg:p-8">{children}</main>
             </div>
          </ThemeProvider>
        </Providers>
      </body>
    </html>
  )
}
