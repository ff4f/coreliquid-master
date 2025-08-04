"use client";

import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Switch } from "@/components/ui/switch";
import { 
  Bell, 
  BellOff, 
  Check, 
  X, 
  Trash2, 
  Settings, 
  Filter, 
  Search, 
  MoreHorizontal, 
  AlertCircle, 
  Info, 
  CheckCircle, 
  XCircle, 
  Clock, 
  Calendar, 
  Users, 
  MessageCircle, 
  Heart, 
  Star, 
  TrendingUp, 
  DollarSign, 
  Shield, 
  Zap, 
  Gift, 
  Award, 
  Target, 
  RefreshCw, 
  Download, 
  Upload, 
  Share2, 
  Bookmark, 
  Flag, 
  Pin, 
  Archive, 
  Inbox, 
  Send, 
  Reply, 
  Forward, 
  Edit, 
  Copy, 
  Link, 
  ExternalLink, 
  ChevronRight, 
  ChevronDown, 
  Plus, 
  Minus, 
  Eye, 
  EyeOff, 
  Volume2, 
  VolumeX,
  ArrowRight,
  Mail,
  Smartphone,
  Monitor
} from "lucide-react";

interface Notification {
  id: string;
  type: 'info' | 'success' | 'warning' | 'error' | 'system' | 'social' | 'transaction' | 'governance' | 'security';
  title: string;
  message: string;
  timestamp: string;
  isRead: boolean;
  isImportant: boolean;
  actionUrl?: string;
  actionText?: string;
  metadata?: {
    amount?: number;
    currency?: string;
    txHash?: string;
    proposalId?: string;
    userId?: string;
    groupId?: string;
    postId?: string;
  };
  sender?: {
    id: string;
    name: string;
    avatar: string;
    role: string;
  };
}

interface NotificationSettings {
  email: {
    enabled: boolean;
    frequency: 'instant' | 'daily' | 'weekly' | 'never';
    types: {
      transactions: boolean;
      governance: boolean;
      security: boolean;
      social: boolean;
      system: boolean;
      marketing: boolean;
    };
  };
  push: {
    enabled: boolean;
    types: {
      transactions: boolean;
      governance: boolean;
      security: boolean;
      social: boolean;
      system: boolean;
    };
  };
  inApp: {
    enabled: boolean;
    sound: boolean;
    desktop: boolean;
    types: {
      transactions: boolean;
      governance: boolean;
      security: boolean;
      social: boolean;
      system: boolean;
    };
  };
  digest: {
    enabled: boolean;
    frequency: 'daily' | 'weekly' | 'monthly';
    time: string;
  };
}

export default function NotificationsPage() {
  const [activeTab, setActiveTab] = useState("all");
  const [searchQuery, setSearchQuery] = useState("");
  const [filterType, setFilterType] = useState("all");
  const [showSettings, setShowSettings] = useState(false);
  const [selectedNotifications, setSelectedNotifications] = useState<string[]>([]);

  const [settings, setSettings] = useState<NotificationSettings>({
    email: {
      enabled: true,
      frequency: 'daily',
      types: {
        transactions: true,
        governance: true,
        security: true,
        social: false,
        system: true,
        marketing: false
      }
    },
    push: {
      enabled: true,
      types: {
        transactions: true,
        governance: true,
        security: true,
        social: true,
        system: true
      }
    },
    inApp: {
      enabled: true,
      sound: true,
      desktop: true,
      types: {
        transactions: true,
        governance: true,
        security: true,
        social: true,
        system: true
      }
    },
    digest: {
      enabled: true,
      frequency: 'weekly',
      time: '09:00'
    }
  });

  const notifications: Notification[] = [
    {
      id: "notif-1",
      type: "transaction",
      title: "Yield Harvest Completed",
      message: "Your yield farming rewards have been automatically harvested and reinvested. Total earned: 45.67 CORE tokens.",
      timestamp: "2024-01-18T14:30:00Z",
      isRead: false,
      isImportant: true,
      actionUrl: "/portfolio",
      actionText: "View Portfolio",
      metadata: {
        amount: 45.67,
        currency: "CORE",
        txHash: "0x1234567890abcdef..."
      }
    },
    {
      id: "notif-2",
      type: "governance",
      title: "New Governance Proposal",
      message: "Proposal CLP-15: Fee Structure Update is now live for voting. Your participation is needed to shape the protocol's future.",
      timestamp: "2024-01-18T12:15:00Z",
      isRead: false,
      isImportant: true,
      actionUrl: "/governance",
      actionText: "Vote Now",
      metadata: {
        proposalId: "CLP-15"
      }
    },
    {
      id: "notif-3",
      type: "security",
      title: "Security Alert: New Login",
      message: "A new login was detected from San Francisco, CA. If this wasn't you, please secure your account immediately.",
      timestamp: "2024-01-18T10:45:00Z",
      isRead: true,
      isImportant: true,
      actionUrl: "/settings/security",
      actionText: "Review Security"
    },
    {
      id: "notif-4",
      type: "social",
      title: "New Reply to Your Post",
      message: "Sarah Chen replied to your post about yield optimization strategies in the DeFi Farmers group.",
      timestamp: "2024-01-18T09:20:00Z",
      isRead: true,
      isImportant: false,
      actionUrl: "/community",
      actionText: "View Reply",
      sender: {
        id: "user-2",
        name: "Sarah Chen",
        avatar: "/avatars/sarah-chen.jpg",
        role: "Community Moderator"
      },
      metadata: {
        postId: "post-1",
        groupId: "group-1"
      }
    },
    {
      id: "notif-5",
      type: "system",
      title: "CoreLiquid V2 Launch",
      message: "CoreLiquid Protocol V2 is now live! Explore new features including multi-chain support and enhanced auto-rebalancing.",
      timestamp: "2024-01-17T16:00:00Z",
      isRead: true,
      isImportant: true,
      actionUrl: "/blog/v2-launch",
      actionText: "Learn More"
    },
    {
      id: "notif-6",
      type: "transaction",
      title: "Auto-Rebalance Executed",
      message: "Your portfolio has been automatically rebalanced to maintain optimal yield. New allocation: 60% USDC, 40% ETH.",
      timestamp: "2024-01-17T14:30:00Z",
      isRead: true,
      isImportant: false,
      actionUrl: "/portfolio",
      actionText: "View Details",
      metadata: {
        txHash: "0xabcdef1234567890..."
      }
    },
    {
      id: "notif-7",
      type: "social",
      title: "New Group Invitation",
      message: "You've been invited to join the 'Security & Audits' private group by Michael Rodriguez.",
      timestamp: "2024-01-17T11:15:00Z",
      isRead: false,
      isImportant: false,
      actionUrl: "/community/groups/security",
      actionText: "Accept Invitation",
      sender: {
        id: "user-3",
        name: "Michael Rodriguez",
        avatar: "/avatars/michael-rodriguez.jpg",
        role: "Security Researcher"
      },
      metadata: {
        groupId: "group-4"
      }
    },
    {
      id: "notif-8",
      type: "warning",
      title: "High Gas Fees Alert",
      message: "Current gas fees are unusually high (150+ gwei). Consider waiting for lower fees before making transactions.",
      timestamp: "2024-01-17T08:45:00Z",
      isRead: true,
      isImportant: false,
      actionUrl: "/analytics/gas",
      actionText: "View Gas Tracker"
    },
    {
      id: "notif-9",
      type: "info",
      title: "Weekly Portfolio Summary",
      message: "Your portfolio gained 3.2% this week. Total value: $12,456.78. Best performing strategy: ETH-USDC LP.",
      timestamp: "2024-01-16T09:00:00Z",
      isRead: true,
      isImportant: false,
      actionUrl: "/analytics",
      actionText: "View Analytics",
      metadata: {
        amount: 12456.78,
        currency: "USD"
      }
    },
    {
      id: "notif-10",
      type: "success",
      title: "Referral Bonus Earned",
      message: "You've earned a 50 CORE referral bonus! Your friend Alex just made their first deposit using your referral link.",
      timestamp: "2024-01-15T15:30:00Z",
      isRead: true,
      isImportant: false,
      actionUrl: "/referrals",
      actionText: "View Referrals",
      metadata: {
        amount: 50,
        currency: "CORE"
      }
    }
  ];

  const getNotificationIcon = (type: string) => {
    switch (type) {
      case 'transaction': return <DollarSign className="w-5 h-5 text-green-600" />;
      case 'governance': return <Shield className="w-5 h-5 text-blue-600" />;
      case 'security': return <AlertCircle className="w-5 h-5 text-red-600" />;
      case 'social': return <MessageCircle className="w-5 h-5 text-purple-600" />;
      case 'system': return <Info className="w-5 h-5 text-blue-600" />;
      case 'success': return <CheckCircle className="w-5 h-5 text-green-600" />;
      case 'warning': return <AlertCircle className="w-5 h-5 text-yellow-600" />;
      case 'error': return <XCircle className="w-5 h-5 text-red-600" />;
      case 'info': return <Info className="w-5 h-5 text-blue-600" />;
      default: return <Bell className="w-5 h-5 text-gray-600" />;
    }
  };

  const getNotificationColor = (type: string) => {
    switch (type) {
      case 'transaction': return 'border-l-green-500';
      case 'governance': return 'border-l-blue-500';
      case 'security': return 'border-l-red-500';
      case 'social': return 'border-l-purple-500';
      case 'system': return 'border-l-blue-500';
      case 'success': return 'border-l-green-500';
      case 'warning': return 'border-l-yellow-500';
      case 'error': return 'border-l-red-500';
      case 'info': return 'border-l-blue-500';
      default: return 'border-l-gray-500';
    }
  };

  const filteredNotifications = notifications.filter(notification => {
    const matchesSearch = notification.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         notification.message.toLowerCase().includes(searchQuery.toLowerCase());
    
    const matchesType = filterType === "all" || notification.type === filterType;
    const matchesTab = activeTab === "all" || 
                      (activeTab === "unread" && !notification.isRead) ||
                      (activeTab === "important" && notification.isImportant);
    
    return matchesSearch && matchesType && matchesTab;
  });

  const unreadCount = notifications.filter(n => !n.isRead).length;
  const importantCount = notifications.filter(n => n.isImportant).length;

  const formatTimeAgo = (dateString: string) => {
    const now = new Date();
    const date = new Date(dateString);
    const diffInMinutes = Math.floor((now.getTime() - date.getTime()) / (1000 * 60));
    
    if (diffInMinutes < 1) return "Just now";
    if (diffInMinutes < 60) return `${diffInMinutes}m ago`;
    if (diffInMinutes < 1440) return `${Math.floor(diffInMinutes / 60)}h ago`;
    if (diffInMinutes < 10080) return `${Math.floor(diffInMinutes / 1440)}d ago`;
    return date.toLocaleDateString();
  };

  const markAsRead = (notificationId: string) => {
    // Implementation would update the notification status
    console.log('Mark as read:', notificationId);
  };

  const markAllAsRead = () => {
    // Implementation would mark all notifications as read
    console.log('Mark all as read');
  };

  const deleteNotification = (notificationId: string) => {
    // Implementation would delete the notification
    console.log('Delete notification:', notificationId);
  };

  const deleteSelected = () => {
    // Implementation would delete selected notifications
    console.log('Delete selected:', selectedNotifications);
    setSelectedNotifications([]);
  };

  const toggleSelection = (notificationId: string) => {
    setSelectedNotifications(prev => 
      prev.includes(notificationId) 
        ? prev.filter(id => id !== notificationId)
        : [...prev, notificationId]
    );
  };

  const selectAll = () => {
    setSelectedNotifications(filteredNotifications.map(n => n.id));
  };

  const clearSelection = () => {
    setSelectedNotifications([]);
  };

  return (
    <div className="container mx-auto p-6 space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Notifications</h1>
          <p className="text-muted-foreground">
            Stay updated with your CoreLiquid activity and important announcements
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" onClick={() => setShowSettings(true)}>
            <Settings className="w-4 h-4 mr-2" />
            Settings
          </Button>
          <Button onClick={markAllAsRead}>
            <Check className="w-4 h-4 mr-2" />
            Mark All Read
          </Button>
        </div>
      </div>

      {/* Search and Filters */}
      <Card>
        <CardContent className="p-6">
          <div className="flex flex-col md:flex-row gap-4">
            <div className="flex-1">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
                <Input
                  placeholder="Search notifications..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-10"
                />
              </div>
            </div>
            
            <div className="flex items-center gap-2">
              <select 
                value={filterType} 
                onChange={(e) => setFilterType(e.target.value)}
                className="px-3 py-2 border rounded-md text-sm"
              >
                <option value="all">All Types</option>
                <option value="transaction">Transactions</option>
                <option value="governance">Governance</option>
                <option value="security">Security</option>
                <option value="social">Social</option>
                <option value="system">System</option>
              </select>
              
              {selectedNotifications.length > 0 && (
                <div className="flex items-center gap-2">
                  <span className="text-sm text-muted-foreground">
                    {selectedNotifications.length} selected
                  </span>
                  <Button size="sm" variant="outline" onClick={deleteSelected}>
                    <Trash2 className="w-4 h-4 mr-1" />
                    Delete
                  </Button>
                  <Button size="sm" variant="outline" onClick={clearSelection}>
                    Clear
                  </Button>
                </div>
              )}
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Notification Tabs */}
      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList className="grid w-full grid-cols-3">
          <TabsTrigger value="all" className="relative">
            All Notifications
            <Badge variant="secondary" className="ml-2">
              {notifications.length}
            </Badge>
          </TabsTrigger>
          <TabsTrigger value="unread" className="relative">
            Unread
            {unreadCount > 0 && (
              <Badge variant="destructive" className="ml-2">
                {unreadCount}
              </Badge>
            )}
          </TabsTrigger>
          <TabsTrigger value="important" className="relative">
            Important
            <Badge variant="secondary" className="ml-2">
              {importantCount}
            </Badge>
          </TabsTrigger>
        </TabsList>

        <TabsContent value={activeTab} className="space-y-4">
          {/* Bulk Actions */}
          {filteredNotifications.length > 0 && (
            <Card>
              <CardContent className="p-4">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-4">
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={selectedNotifications.length === filteredNotifications.length ? clearSelection : selectAll}
                    >
                      {selectedNotifications.length === filteredNotifications.length ? (
                        <>
                          <Minus className="w-4 h-4 mr-1" />
                          Deselect All
                        </>
                      ) : (
                        <>
                          <Check className="w-4 h-4 mr-1" />
                          Select All
                        </>
                      )}
                    </Button>
                    
                    <span className="text-sm text-muted-foreground">
                      {filteredNotifications.length} notification{filteredNotifications.length !== 1 ? 's' : ''}
                    </span>
                  </div>
                  
                  <Button size="sm" variant="outline">
                    <RefreshCw className="w-4 h-4 mr-1" />
                    Refresh
                  </Button>
                </div>
              </CardContent>
            </Card>
          )}

          {/* Notifications List */}
          {filteredNotifications.length === 0 ? (
            <Card>
              <CardContent className="p-12 text-center">
                <Bell className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                <h3 className="text-lg font-semibold text-gray-600 mb-2">No notifications found</h3>
                <p className="text-muted-foreground mb-4">
                  {searchQuery || filterType !== "all" ? 
                    "Try adjusting your search terms or filters" :
                    "You're all caught up! No new notifications."
                  }
                </p>
                {(searchQuery || filterType !== "all") && (
                  <Button onClick={() => { 
                    setSearchQuery(""); 
                    setFilterType("all");
                  }}>
                    Clear Filters
                  </Button>
                )}
              </CardContent>
            </Card>
          ) : (
            <div className="space-y-2">
              {filteredNotifications.map(notification => (
                <Card key={notification.id} className={`transition-all hover:shadow-md ${
                  !notification.isRead ? 'bg-blue-50/50 border-l-4' : 'border-l-4'
                } ${getNotificationColor(notification.type)} ${
                  selectedNotifications.includes(notification.id) ? 'ring-2 ring-blue-500' : ''
                }`}>
                  <CardContent className="p-4">
                    <div className="flex gap-4">
                      <div className="flex items-start gap-3">
                        <input
                          type="checkbox"
                          checked={selectedNotifications.includes(notification.id)}
                          onChange={() => toggleSelection(notification.id)}
                          className="mt-1"
                        />
                        
                        <div className="flex-shrink-0 mt-1">
                          {notification.sender ? (
                            <Avatar className="w-10 h-10">
                              <AvatarImage src={notification.sender.avatar} />
                              <AvatarFallback>
                                {notification.sender.name.split(' ').map(n => n[0]).join('')}
                              </AvatarFallback>
                            </Avatar>
                          ) : (
                            <div className="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center">
                              {getNotificationIcon(notification.type)}
                            </div>
                          )}
                        </div>
                      </div>
                      
                      <div className="flex-1 min-w-0">
                        <div className="flex items-start justify-between gap-2 mb-2">
                          <div className="flex-1">
                            <div className="flex items-center gap-2 mb-1">
                              <h3 className={`font-semibold ${
                                !notification.isRead ? 'text-gray-900' : 'text-gray-700'
                              }`}>
                                {notification.title}
                              </h3>
                              {notification.isImportant && (
                                <Star className="w-4 h-4 text-yellow-500 fill-current" />
                              )}
                              {!notification.isRead && (
                                <div className="w-2 h-2 bg-blue-500 rounded-full" />
                              )}
                            </div>
                            
                            <div className="flex items-center gap-2 text-xs text-muted-foreground mb-2">
                              <Badge variant="outline" className="text-xs capitalize">
                                {notification.type}
                              </Badge>
                              <span>•</span>
                              <span className="flex items-center gap-1">
                                <Clock className="w-3 h-3" />
                                {formatTimeAgo(notification.timestamp)}
                              </span>
                              {notification.sender && (
                                <>
                                  <span>•</span>
                                  <span>from {notification.sender.name}</span>
                                </>
                              )}
                            </div>
                          </div>
                          
                          <div className="flex items-center gap-1">
                            {!notification.isRead && (
                              <Button
                                size="sm"
                                variant="ghost"
                                onClick={() => markAsRead(notification.id)}
                                title="Mark as read"
                              >
                                <Eye className="w-4 h-4" />
                              </Button>
                            )}
                            <Button
                              size="sm"
                              variant="ghost"
                              onClick={() => deleteNotification(notification.id)}
                              title="Delete notification"
                            >
                              <Trash2 className="w-4 h-4" />
                            </Button>
                            <Button size="sm" variant="ghost" title="More options">
                              <MoreHorizontal className="w-4 h-4" />
                            </Button>
                          </div>
                        </div>
                        
                        <p className="text-muted-foreground text-sm mb-3 line-clamp-2">
                          {notification.message}
                        </p>
                        
                        {notification.metadata && (
                          <div className="flex items-center gap-4 text-xs text-muted-foreground mb-3">
                            {notification.metadata.amount && (
                              <span className="flex items-center gap-1">
                                <DollarSign className="w-3 h-3" />
                                {notification.metadata.amount} {notification.metadata.currency}
                              </span>
                            )}
                            {notification.metadata.txHash && (
                              <span className="flex items-center gap-1">
                                <Link className="w-3 h-3" />
                                {notification.metadata.txHash.slice(0, 10)}...
                              </span>
                            )}
                            {notification.metadata.proposalId && (
                              <span className="flex items-center gap-1">
                                <Shield className="w-3 h-3" />
                                {notification.metadata.proposalId}
                              </span>
                            )}
                          </div>
                        )}
                        
                        {notification.actionUrl && notification.actionText && (
                          <div className="flex items-center gap-2">
                            <Button size="sm" variant="outline">
                              {notification.actionText}
                              <ArrowRight className="w-3 h-3 ml-1" />
                            </Button>
                            <Button size="sm" variant="ghost">
                              <Share2 className="w-4 h-4" />
                            </Button>
                          </div>
                        )}
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </TabsContent>
      </Tabs>

      {/* Settings Modal */}
      {showSettings && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <Card className="w-full max-w-4xl max-h-[90vh] overflow-y-auto">
            <CardHeader>
              <div className="flex items-center justify-between">
                <div>
                  <CardTitle>Notification Settings</CardTitle>
                  <CardDescription>
                    Customize how and when you receive notifications
                  </CardDescription>
                </div>
                <Button variant="ghost" onClick={() => setShowSettings(false)}>
                  <X className="w-4 h-4" />
                </Button>
              </div>
            </CardHeader>
            <CardContent className="space-y-6">
              {/* Email Notifications */}
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <div>
                    <h3 className="font-semibold flex items-center gap-2">
                      <Mail className="w-5 h-5" />
                      Email Notifications
                    </h3>
                    <p className="text-sm text-muted-foreground">
                      Receive notifications via email
                    </p>
                  </div>
                  <Switch
                    checked={settings.email.enabled}
                    onCheckedChange={(checked) => 
                      setSettings(prev => ({
                        ...prev,
                        email: { ...prev.email, enabled: checked }
                      }))
                    }
                  />
                </div>
                
                {settings.email.enabled && (
                  <div className="ml-7 space-y-4">
                    <div>
                      <label className="text-sm font-medium">Frequency</label>
                      <select 
                        value={settings.email.frequency}
                        onChange={(e) => 
                          setSettings(prev => ({
                            ...prev,
                            email: { ...prev.email, frequency: e.target.value as any }
                          }))
                        }
                        className="w-full mt-1 p-2 border rounded-md text-sm"
                      >
                        <option value="instant">Instant</option>
                        <option value="daily">Daily Digest</option>
                        <option value="weekly">Weekly Digest</option>
                        <option value="never">Never</option>
                      </select>
                    </div>
                    
                    <div className="space-y-3">
                      <label className="text-sm font-medium">Notification Types</label>
                      {Object.entries(settings.email.types).map(([type, enabled]) => (
                        <div key={type} className="flex items-center justify-between">
                          <span className="text-sm capitalize">{type.replace(/([A-Z])/g, ' $1')}</span>
                          <Switch
                            checked={enabled}
                            onCheckedChange={(checked) => 
                              setSettings(prev => ({
                                ...prev,
                                email: {
                                  ...prev.email,
                                  types: { ...prev.email.types, [type]: checked }
                                }
                              }))
                            }
                          />
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>

              {/* Push Notifications */}
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <div>
                    <h3 className="font-semibold flex items-center gap-2">
                      <Smartphone className="w-5 h-5" />
                      Push Notifications
                    </h3>
                    <p className="text-sm text-muted-foreground">
                      Receive push notifications on your device
                    </p>
                  </div>
                  <Switch
                    checked={settings.push.enabled}
                    onCheckedChange={(checked) => 
                      setSettings(prev => ({
                        ...prev,
                        push: { ...prev.push, enabled: checked }
                      }))
                    }
                  />
                </div>
                
                {settings.push.enabled && (
                  <div className="ml-7 space-y-3">
                    {Object.entries(settings.push.types).map(([type, enabled]) => (
                      <div key={type} className="flex items-center justify-between">
                        <span className="text-sm capitalize">{type.replace(/([A-Z])/g, ' $1')}</span>
                        <Switch
                          checked={enabled}
                          onCheckedChange={(checked) => 
                            setSettings(prev => ({
                              ...prev,
                              push: {
                                ...prev.push,
                                types: { ...prev.push.types, [type]: checked }
                              }
                            }))
                          }
                        />
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* In-App Notifications */}
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <div>
                    <h3 className="font-semibold flex items-center gap-2">
                      <Monitor className="w-5 h-5" />
                      In-App Notifications
                    </h3>
                    <p className="text-sm text-muted-foreground">
                      Show notifications within the application
                    </p>
                  </div>
                  <Switch
                    checked={settings.inApp.enabled}
                    onCheckedChange={(checked) => 
                      setSettings(prev => ({
                        ...prev,
                        inApp: { ...prev.inApp, enabled: checked }
                      }))
                    }
                  />
                </div>
                
                {settings.inApp.enabled && (
                  <div className="ml-7 space-y-4">
                    <div className="flex items-center justify-between">
                      <span className="text-sm">Sound notifications</span>
                      <Switch
                        checked={settings.inApp.sound}
                        onCheckedChange={(checked) => 
                          setSettings(prev => ({
                            ...prev,
                            inApp: { ...prev.inApp, sound: checked }
                          }))
                        }
                      />
                    </div>
                    
                    <div className="flex items-center justify-between">
                      <span className="text-sm">Desktop notifications</span>
                      <Switch
                        checked={settings.inApp.desktop}
                        onCheckedChange={(checked) => 
                          setSettings(prev => ({
                            ...prev,
                            inApp: { ...prev.inApp, desktop: checked }
                          }))
                        }
                      />
                    </div>
                    
                    <div className="space-y-3">
                      <label className="text-sm font-medium">Notification Types</label>
                      {Object.entries(settings.inApp.types).map(([type, enabled]) => (
                        <div key={type} className="flex items-center justify-between">
                          <span className="text-sm capitalize">{type.replace(/([A-Z])/g, ' $1')}</span>
                          <Switch
                            checked={enabled}
                            onCheckedChange={(checked) => 
                              setSettings(prev => ({
                                ...prev,
                                inApp: {
                                  ...prev.inApp,
                                  types: { ...prev.inApp.types, [type]: checked }
                                }
                              }))
                            }
                          />
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>

              {/* Digest Settings */}
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <div>
                    <h3 className="font-semibold flex items-center gap-2">
                      <Calendar className="w-5 h-5" />
                      Digest Summary
                    </h3>
                    <p className="text-sm text-muted-foreground">
                      Receive periodic summaries of your activity
                    </p>
                  </div>
                  <Switch
                    checked={settings.digest.enabled}
                    onCheckedChange={(checked) => 
                      setSettings(prev => ({
                        ...prev,
                        digest: { ...prev.digest, enabled: checked }
                      }))
                    }
                  />
                </div>
                
                {settings.digest.enabled && (
                  <div className="ml-7 space-y-4">
                    <div>
                      <label className="text-sm font-medium">Frequency</label>
                      <select 
                        value={settings.digest.frequency}
                        onChange={(e) => 
                          setSettings(prev => ({
                            ...prev,
                            digest: { ...prev.digest, frequency: e.target.value as any }
                          }))
                        }
                        className="w-full mt-1 p-2 border rounded-md text-sm"
                      >
                        <option value="daily">Daily</option>
                        <option value="weekly">Weekly</option>
                        <option value="monthly">Monthly</option>
                      </select>
                    </div>
                    
                    <div>
                      <label className="text-sm font-medium">Delivery Time</label>
                      <Input
                        type="time"
                        value={settings.digest.time}
                        onChange={(e) => 
                          setSettings(prev => ({
                            ...prev,
                            digest: { ...prev.digest, time: e.target.value }
                          }))
                        }
                        className="mt-1"
                      />
                    </div>
                  </div>
                )}
              </div>
              
              <div className="flex gap-3 pt-4">
                <Button className="flex-1">
                  <Check className="w-4 h-4 mr-2" />
                  Save Settings
                </Button>
                <Button variant="outline" onClick={() => setShowSettings(false)}>
                  Cancel
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
}