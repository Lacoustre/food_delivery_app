import { useState, useEffect } from "react";
import { Bell, AlertCircle, ShoppingBag, Star, Clock, Filter } from "lucide-react";
import { useCollectionData } from "react-firebase-hooks/firestore";
import { collection, query, orderBy, limit, where, Timestamp } from "firebase/firestore";
import { db } from "../firebase";
import { useNavigate } from "react-router-dom";
import moment from "moment";

interface Notification {
  id: string;
  type: "order" | "review" | "alert" | "system";
  title: string;
  message: string;
  createdAt: Timestamp;
  read: boolean;
  priority: "low" | "medium" | "high";
  orderId?: string;
  actionUrl?: string;
}

export default function Notifications() {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [filter, setFilter] = useState<"all" | "unread" | "order" | "review" | "alert">("all");
  const navigate = useNavigate();

  // Real-time queries for generating notifications
  const [newOrders] = useCollectionData(
    query(collection(db, "orders"), where("status", "==", "pending"), orderBy("createdAt", "desc"), limit(20))
  );
  const [newReviews] = useCollectionData(
    query(collection(db, "reviews"), orderBy("createdAt", "desc"), limit(10))
  );
  const [lowStockMeals] = useCollectionData(
    query(collection(db, "meals"), where("active", "==", false))
  );

  // Generate notifications from data
  useEffect(() => {
    const generatedNotifications: Notification[] = [];

    // New order notifications
    newOrders?.forEach((order) => {
      generatedNotifications.push({
        id: `order-${order.id}`,
        type: "order",
        title: "New Order Received",
        message: `Order from ${order.customerName || order.name || order.customer || "Customer"} - $${(order.pricing?.total || order.total || 0).toFixed(2)}`,
        createdAt: order.createdAt || Timestamp.now(),
        read: false,
        priority: "high",
        orderId: order.id,
        actionUrl: "/orders"
      });
    });

    // New review notifications
    newReviews?.forEach((review) => {
      generatedNotifications.push({
        id: `review-${review.id}`,
        type: "review",
        title: "New Customer Review",
        message: `${review.rating}⭐ from ${review.customerName || "Anonymous"}`,
        createdAt: review.createdAt || Timestamp.now(),
        read: false,
        priority: "medium",
        actionUrl: "/"
      });
    });

    // Low stock alerts
    if (lowStockMeals && lowStockMeals.length > 0) {
      generatedNotifications.push({
        id: "low-stock",
        type: "alert",
        title: "Inactive Menu Items",
        message: `${lowStockMeals.length} menu items are currently inactive`,
        createdAt: Timestamp.now(),
        read: false,
        priority: "medium",
        actionUrl: "/meals"
      });
    }

    // Sort by priority and time
    generatedNotifications.sort((a, b) => {
      const priorityOrder = { high: 3, medium: 2, low: 1 };
      if (priorityOrder[a.priority] !== priorityOrder[b.priority]) {
        return priorityOrder[b.priority] - priorityOrder[a.priority];
      }
      return (b.createdAt?.seconds || 0) - (a.createdAt?.seconds || 0);
    });

    setNotifications(generatedNotifications);
  }, [newOrders, newReviews, lowStockMeals]);

  const filteredNotifications = notifications.filter(notification => {
    switch (filter) {
      case "unread": return !notification.read;
      case "order": return notification.type === "order";
      case "review": return notification.type === "review";
      case "alert": return notification.type === "alert";
      default: return true;
    }
  });

  const getIcon = (type: string) => {
    switch (type) {
      case "order": return <ShoppingBag className="w-5 h-5 text-blue-600" />;
      case "review": return <Star className="w-5 h-5 text-yellow-600" />;
      case "alert": return <AlertCircle className="w-5 h-5 text-red-600" />;
      default: return <Clock className="w-5 h-5 text-gray-600" />;
    }
  };

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case "high": return "border-l-red-500 bg-red-50";
      case "medium": return "border-l-yellow-500 bg-yellow-50";
      default: return "border-l-gray-500 bg-gray-50";
    }
  };

  const handleNotificationClick = (notification: Notification) => {
    // Mark as read
    setNotifications(prev => 
      prev.map(n => n.id === notification.id ? { ...n, read: true } : n)
    );
    
    if (notification.actionUrl) {
      navigate(notification.actionUrl);
    }
  };

  const markAllAsRead = () => {
    setNotifications(prev => prev.map(n => ({ ...n, read: true })));
  };

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Notifications</h1>
        <p className="text-gray-600">Stay updated with your restaurant's activities.</p>
      </div>

      {/* Filter and Actions */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-6">
        <div className="flex flex-col sm:flex-row gap-4 items-start sm:items-center justify-between">
          <div className="flex items-center gap-4">
            <Filter className="text-gray-400 w-5 h-5" />
            <select
              value={filter}
              onChange={(e) => setFilter(e.target.value as "all" | "unread" | "order" | "review" | "alert")}
              className="border border-gray-300 px-3 py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors"
            >
              <option value="all">All Notifications</option>
              <option value="unread">Unread Only</option>
              <option value="order">Orders</option>
              <option value="review">Reviews</option>
              <option value="alert">Alerts</option>
            </select>
          </div>
          
          <button
            onClick={markAllAsRead}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors text-sm font-medium"
          >
            Mark All as Read
          </button>
        </div>
      </div>

      {/* Notifications List */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">
            {filter === "all" ? "All Notifications" : 
             filter === "unread" ? "Unread Notifications" :
             filter.charAt(0).toUpperCase() + filter.slice(1) + " Notifications"} 
            ({filteredNotifications.length})
          </h2>
        </div>

        {filteredNotifications.length === 0 ? (
          <div className="p-12 text-center text-gray-500">
            <Bell className="w-16 h-16 mx-auto mb-4 text-gray-300" />
            <p className="text-lg font-medium mb-2">No notifications found</p>
            <p>You're all caught up!</p>
          </div>
        ) : (
          <div className="divide-y divide-gray-200">
            {filteredNotifications.map((notification) => (
              <div
                key={notification.id}
                className={`p-6 border-l-4 hover:bg-gray-50 cursor-pointer transition-colors duration-150 ${
                  getPriorityColor(notification.priority)
                } ${!notification.read ? 'bg-blue-50' : ''}`}
                onClick={() => handleNotificationClick(notification)}
              >
                <div className="flex items-start gap-4">
                  <div className="flex-shrink-0 mt-1">
                    {getIcon(notification.type)}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between mb-2">
                      <h3 className={`text-lg font-medium ${
                        !notification.read ? 'text-gray-900' : 'text-gray-700'
                      }`}>
                        {notification.title}
                      </h3>
                      <div className="flex items-center gap-2">
                        <span className={`px-2 py-1 text-xs font-medium rounded-full ${
                          notification.priority === 'high' ? 'bg-red-100 text-red-800' :
                          notification.priority === 'medium' ? 'bg-yellow-100 text-yellow-800' :
                          'bg-gray-100 text-gray-800'
                        }`}>
                          {notification.priority}
                        </span>
                        {!notification.read && (
                          <div className="w-3 h-3 bg-blue-500 rounded-full"></div>
                        )}
                      </div>
                    </div>
                    <p className="text-gray-600 mb-3">
                      {notification.message}
                    </p>
                    <div className="flex items-center justify-between">
                      <p className="text-sm text-gray-500">
                        {notification.createdAt?.seconds 
                          ? moment(notification.createdAt.seconds * 1000).format("MMM D, YYYY [at] h:mm A")
                          : 'Just now'
                        }
                      </p>
                      {notification.actionUrl && (
                        <span className="text-sm text-blue-600 font-medium">
                          Click to view details →
                        </span>
                      )}
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}