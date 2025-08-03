"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { BarChart3, PlusCircle, TrendingDown, ArrowLeftRight, Vault, Shield, Gift, Vote } from "lucide-react"
import { cn } from "@/lib/utils"

const menuItems = [
  {
    title: "DASHBOARD",
    icon: BarChart3,
    href: "/dashboard",
    color: "cyan",
  },
  {
    title: "DEPOSIT",
    icon: PlusCircle,
    href: "/deposit",
    color: "green",
  },
  {
    title: "CREDIT SALE",
    icon: TrendingDown,
    href: "/credit-sale",
    color: "cyan",
  },
  {
    title: "SWAP",
    icon: ArrowLeftRight,
    href: "/swap",
    color: "blue",
  },
  {
    title: "VAULT",
    icon: Vault,
    href: "/vault",
    color: "purple",
  },
  {
    title: "RISK",
    icon: Shield,
    href: "/risk",
    color: "orange",
  },
  {
    title: "REBALANCING",
    icon: BarChart3,
    href: "/rebalancing",
    color: "cyan",
  },
  {
    title: "REWARDS",
    icon: Gift,
    href: "/rewards",
    color: "yellow",
  },
  {
    title: "GOVERNANCE",
    icon: Vote,
    href: "/governance",
    color: "pink",
  },
]

const colorMap = {
  cyan: "text-cyan-400 border-cyan-500 bg-cyan-500/10 shadow-[0_0_15px_rgba(6,182,212,0.3)]",
  green: "text-green-400 border-green-500 bg-green-500/10 shadow-[0_0_15px_rgba(34,197,94,0.3)]",
  red: "text-red-400 border-red-500 bg-red-500/10 shadow-[0_0_15px_rgba(239,68,68,0.3)]",
  blue: "text-blue-400 border-blue-500 bg-blue-500/10 shadow-[0_0_15px_rgba(59,130,246,0.3)]",
  purple: "text-purple-400 border-purple-500 bg-purple-500/10 shadow-[0_0_15px_rgba(147,51,234,0.3)]",
  orange: "text-orange-400 border-orange-500 bg-orange-500/10 shadow-[0_0_15px_rgba(249,115,22,0.3)]",
  yellow: "text-yellow-400 border-yellow-500 bg-yellow-500/10 shadow-[0_0_15px_rgba(234,179,8,0.3)]",
  pink: "text-pink-400 border-pink-500 bg-pink-500/10 shadow-[0_0_15px_rgba(236,72,153,0.3)]",
}

export function HorizontalNav() {
  const pathname = usePathname()

  return (
    <nav className="border-b border-blue-500/20 bg-black/40 backdrop-blur-md relative z-10">
      <div className="px-6">
        <div className="flex space-x-1 overflow-x-auto">
          {menuItems.map((item) => {
            const isActive = pathname === item.href
            return (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  "flex items-center space-x-2 px-6 py-4 text-sm font-mono tracking-wider transition-all duration-300 whitespace-nowrap border-b-2 border-transparent relative group",
                  isActive
                    ? colorMap[item.color as keyof typeof colorMap]
                    : "text-gray-400 hover:text-white hover:bg-white/5",
                )}
                style={{
                  clipPath: isActive ? "polygon(10px 0, 100% 0, calc(100% - 10px) 100%, 0 100%)" : "none",
                  textShadow: isActive ? "0 0 10px currentColor" : "none",
                }}
              >
                <item.icon className="w-4 h-4" />
                <span>[{item.title}]</span>
                {isActive && (
                  <div className="absolute inset-0 bg-gradient-to-r from-transparent via-current/10 to-transparent opacity-20"></div>
                )}
              </Link>
            )
          })}
        </div>
      </div>
    </nav>
  )
}
