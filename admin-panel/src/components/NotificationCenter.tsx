import { useState, useEffect, useCallback } from "react";
import { Bell, X, AlertCircle, ShoppingBag, Star, Clock, ExternalLink } from "lucide-react";
import { supabase } from "../lib/supabase";
import { useNavigate } from "react-router-dom";
import moment from "moment";

interface Notification {
  id: string;
  type: "order" | "review" | "alert" | "system";
  title: string;
  message: string;
  createdAtMs: number;
  read: boolean;
  priority: "low" | "medium" | "high";
  orderId?: string;
  actionUrl?: string;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function profileOf(row: any): { name?: string | null; email?: string | null } | null {
  return Array.isArray(row.profiles) ? row.profiles[0] ?? null : row.profiles;
}

export default function NotificationCenter() {
  const [isOpen, setIsOpen] = useState(false);
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const navigate = useNavigate();

  // Track previous notification count for sound alerts
  const [prevNotificationCount, setPrevNotificationCount] = useState(0);

  // Notifications are derived from Supabase: pending orders needing
  // confirmation, recent orders, latest reviews, inactive meals.
  const buildNotifications = useCallback(async () => {
    const [ordersRes, pendingRes, reviewsRes, mealsRes] = await Promise.all([
      supabase
        .from("orders")
        .select("id, status, total, created_at, profiles!user_id(name, email)")
        .order("created_at", { ascending: false })
        .limit(20),
      supabase
        .from("orders")
        .select("id, total, created_at, profiles!user_id(name, email)")
        .eq("status", "pending")
        .order("created_at", { ascending: false })
        .limit(10),
      supabase
        .from("order_reviews")
        .select("id, rating, created_at, profiles(name)")
        .order("created_at", { ascending: false })
        .limit(3),
      supabase.from("meals").select("id").eq("active", false),
    ]);

    const generatedNotifications: Notification[] = [];

    // Priority 1: Pending orders needing confirmation
    (pendingRes.data ?? []).forEach((order, index) => {
      if (index < 5) {
        const profile = profileOf(order);
        generatedNotifications.push({
          id: `received-${order.id}`,
          type: "order",
          title: "🚨 New Order - Needs Confirmation",
          message: `URGENT: Order from ${profile?.name || profile?.email || "Customer"} - $${Number(order.total ?? 0).toFixed(2)}`,
          createdAtMs: order.created_at ? new Date(order.created_at).getTime() : Date.now(),
          read: false,
          priority: "high",
          orderId: order.id,
          actionUrl: "/orders?filter=pending"
        });
      }
    });

    // Priority 2: Recent orders from last 30 minutes
    const thirtyMinutesAgo = Date.now() - (30 * 60 * 1000);
    const recentOrders = (ordersRes.data ?? []).filter(order => {
      const orderTime = order.created_at ? new Date(order.created_at).getTime() : 0;
      return orderTime > thirtyMinutesAgo && order.status !== 'pending'; // pending already shown above
    });

    recentOrders.forEach((order, index) => {
      if (index < 3) {
        const profile = profileOf(order);
        generatedNotifications.push({
          id: `recent-${order.id}`,
          type: "order",
          title: "Recent Order",
          message: `Order from ${profile?.name || profile?.email || 'Customer'} - $${Number(order.total ?? 0).toFixed(2)} (${order.status})`,
          createdAtMs: order.created_at ? new Date(order.created_at).getTime() : Date.now(),
          read: false,
          priority: "medium",
          orderId: order.id,
          actionUrl: "/orders"
        });
      }
    });

    // New review notifications
    (reviewsRes.data ?? []).forEach((review, index) => {
      if (index < 2) {
        const profile = profileOf(review);
        generatedNotifications.push({
          id: `review-${review.id}`,
          type: "review",
          title: "New Customer Review",
          message: `${review.rating}⭐ from ${profile?.name || "Anonymous"}`,
          createdAtMs: review.created_at ? new Date(review.created_at).getTime() : Date.now(),
          read: false,
          priority: "medium"
        });
      }
    });

    // Low stock alerts
    const inactiveMeals = mealsRes.data ?? [];
    if (inactiveMeals.length > 0) {
      generatedNotifications.push({
        id: "low-stock",
        type: "alert",
        title: "Inactive Menu Items",
        message: `${inactiveMeals.length} menu items are currently inactive`,
        createdAtMs: Date.now(),
        read: false,
        priority: "medium"
      });
    }

    // Sort by priority and time
    generatedNotifications.sort((a, b) => {
      const priorityOrder = { high: 3, medium: 2, low: 1 };
      if (priorityOrder[a.priority] !== priorityOrder[b.priority]) {
        return priorityOrder[b.priority] - priorityOrder[a.priority];
      }
      return b.createdAtMs - a.createdAtMs;
    });
    return generatedNotifications;
  }, []);

  useEffect(() => {
    const refresh = async () => {
      const generatedNotifications = await buildNotifications();
      const limitedNotifications = generatedNotifications.slice(0, 10);

      // Play sound if new notifications arrived
      setPrevNotificationCount((prevCount) => {
        if (limitedNotifications.length > prevCount && prevCount > 0) {
          // Create a simple beep sound using Web Audio API
          try {
            const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
            const oscillator = audioContext.createOscillator();
            const gainNode = audioContext.createGain();

            oscillator.connect(gainNode);
            gainNode.connect(audioContext.destination);

            oscillator.frequency.setValueAtTime(800, audioContext.currentTime);
            oscillator.type = 'sine';

            gainNode.gain.setValueAtTime(0.1, audioContext.currentTime);
            gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.3);

            oscillator.start(audioContext.currentTime);
            oscillator.stop(audioContext.currentTime + 0.3);
          } catch (error) {
            console.log('Audio notification not available');
          }
        }
        return limitedNotifications.length;
      });
      setNotifications(limitedNotifications);
    };

    refresh();
    const channel = supabase
      .channel("notification-center")
      .on("postgres_changes", { event: "*", schema: "public", table: "orders" }, refresh)
      .on("postgres_changes", { event: "*", schema: "public", table: "order_reviews" }, refresh)
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [buildNotifications]);

  const unreadCount = notifications.filter(n => !n.read).length;

  const getIcon = (type: string) => {
    switch (type) {
      case "order": return <ShoppingBag className="w-4 h-4 text-blue-600" />;
      case "review": return <Star className="w-4 h-4 text-yellow-600" />;
      case "alert": return <AlertCircle className="w-4 h-4 text-red-600" />;
      default: return <Clock className="w-4 h-4 text-gray-600" />;
    }
  };

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case "high": return "border-l-red-500 bg-red-50";
      case "medium": return "border-l-yellow-500 bg-yellow-50";
      default: return "border-l-gray-500 bg-gray-50";
    }
  };

  const markAsRead = (id: string) => {
    setNotifications(prev => 
      prev.map(n => n.id === id ? { ...n, read: true } : n)
    );
  };

  const markAllAsRead = () => {
    setNotifications(prev => prev.map(n => ({ ...n, read: true })));
  };

  const handleNotificationClick = (notification: Notification) => {
    markAsRead(notification.id);
    setIsOpen(false);
    
    if (notification.actionUrl) {
      navigate(notification.actionUrl);
    }
  };

  return (
    <div className="relative">
      {/* Notification Bell */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="relative p-2 text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-colors duration-200"
      >
        <Bell className="w-6 h-6" />
        {unreadCount > 0 && (
          <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full w-5 h-5 flex items-center justify-center font-medium">
            {unreadCount > 9 ? "9+" : unreadCount}
          </span>
        )}
      </button>

      {/* Notification Dropdown */}
      {isOpen && (
        <div className="absolute right-0 mt-2 w-80 bg-white rounded-xl shadow-lg border border-gray-200 z-50">
          <div className="p-4 border-b border-gray-200">
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-semibold text-gray-900">Notifications</h3>
              <div className="flex items-center gap-2">
                {unreadCount > 0 && (
                  <button
                    onClick={markAllAsRead}
                    className="text-xs text-blue-600 hover:text-blue-800 font-medium"
                  >
                    Mark all read
                  </button>
                )}
                <button
                  onClick={() => setIsOpen(false)}
                  className="text-gray-400 hover:text-gray-600"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
            </div>
          </div>

          <div className="max-h-96 overflow-y-auto">
            {notifications.length === 0 ? (
              <div className="p-6 text-center text-gray-500">
                <Bell className="w-12 h-12 mx-auto mb-2 text-gray-300" />
                <p>No notifications</p>
              </div>
            ) : (
              notifications.map((notification) => (
                <div
                  key={notification.id}
                  className={`p-4 border-l-4 hover:bg-gray-50 cursor-pointer transition-colors duration-150 ${
                    getPriorityColor(notification.priority)
                  } ${!notification.read ? 'bg-blue-50' : ''}`}
                  onClick={() => handleNotificationClick(notification)}
                >
                  <div className="flex items-start gap-3">
                    <div className="flex-shrink-0 mt-1">
                      {getIcon(notification.type)}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between">
                        <p className={`text-sm font-medium ${
                          !notification.read ? 'text-gray-900' : 'text-gray-700'
                        }`}>
                          {notification.title}
                        </p>
                        {!notification.read && (
                          <div className="w-2 h-2 bg-blue-500 rounded-full flex-shrink-0"></div>
                        )}
                      </div>
                      <p className="text-sm text-gray-600 mt-1">
                        {notification.message}
                      </p>
                      <div className="flex items-center justify-between mt-2">
                        <p className="text-xs text-gray-500">
                          {notification.createdAtMs
                            ? moment(notification.createdAtMs).fromNow()
                            : 'Just now'
                          }
                        </p>
                        {notification.actionUrl && (
                          <div className="flex items-center gap-1 text-xs text-blue-600">
                            <span>Click to view</span>
                            <ExternalLink className="w-3 h-3" />
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>

          {notifications.length > 0 && (
            <div className="p-3 border-t border-gray-200 text-center">
              <button 
                onClick={() => {
                  setIsOpen(false);
                  navigate('/notifications');
                }}
                className="text-sm text-blue-600 hover:text-blue-800 font-medium"
              >
                View all notifications
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}