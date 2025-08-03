"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import { BarChart3, PlusCircle, TrendingDown, ArrowLeftRight, Vault, Shield, Gift, Vote } from "lucide-react"
import { cn } from "@/lib/utils"

const menuItems = [
  {
    title: "Dashboard",
    icon: BarChart3,
    href: "/dashboard",
  },
  {
    title: "Deposit",
    icon: PlusCircle,
    href: "/deposit",
  },
  {
    title: "Credit Sale",
    icon: TrendingDown,
    href: "/credit-sale",
  },
  {
    title: "Swap",
    icon: ArrowLeftRight,
    href: "/swap",
  },
  {
    title: "Vault",
    icon: Vault,
    href: "/vault",
  },
  {
    title: "Risk",
    icon: Shield,
    href: "/risk",
  },
  {
    title: "Rebalancing",
    icon: BarChart3,
    href: "/rebalancing",
  },
  {
    title: "Rewards",
    icon: Gift,
    href: "/rewards",
  },
  {
    title: "Governance",
    icon: Vote,
    href: "/governance",
  },
]

export function MobileNav() {
  const pathname = usePathname()

  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-[#1E1E1E] border-t border-[#2A2A2A] md:hidden">
      <div className="grid grid-cols-4 gap-1">
        {menuItems.slice(0, 4).map((item) => {
          const isActive = pathname === item.href
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex flex-col items-center justify-center py-2 px-1 text-xs transition-colors",
                isActive ? "text-blue-500 bg-blue-500/10" : "text-gray-400 hover:text-white",
              )}
            >
              <item.icon className="w-5 h-5 mb-1" />
              <span className="truncate">{item.title}</span>
            </Link>
          )
        })}
      </div>
      <div className="grid grid-cols-4 gap-1">
        {menuItems.slice(4).map((item) => {
          const isActive = pathname === item.href
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "flex flex-col items-center justify-center py-2 px-1 text-xs transition-colors",
                isActive ? "text-blue-500 bg-blue-500/10" : "text-gray-400 hover:text-white",
              )}
            >
              <item.icon className="w-5 h-5 mb-1" />
              <span className="truncate">{item.title}</span>
            </Link>
          )
        })}
      </div>
    </nav>
  )
}
