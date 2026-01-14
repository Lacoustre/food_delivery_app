import { Link } from "react-router-dom";
import { useState, useEffect, useCallback } from "react";
import {
  Users,
  Utensils,
  ShoppingBag,
  DollarSign,
  TrendingUp,
  Clock,
  Calendar,
  Star,
  Activity,
  ArrowUp,
  ArrowDown,
} from "lucide-react";
import {
  collection,
  query,
  where,
  orderBy,
  limit,
  doc,
} from "firebase/firestore";
import { useCollectionData, useDocumentData, useCollection } from "react-firebase-hooks/firestore";
import { useAuthState } from "react-firebase-hooks/auth";
import { db, auth } from "../firebase";
import Loader from "../components/Loader";
import moment from "moment";

interface Order {
  id: string;
  status: string;
  createdAt?: { seconds: number };
  updatedAt?: { seconds: number };
  confirmedTime?: { seconds: number };
  preparingTime?: { seconds: number };
  readyTime?: { seconds: number };
  pickedUpTime?: { seconds: number };
  deliveredTime?: { seconds: number };
  pricing?: { total?: number };
  total?: number;
  orderType?: string;
  deliveryMethod?: string;
  switchedToPickup?: boolean;
  customerName?: string;
  name?: string;
  customer?: string;
  userId?: string;
}

interface User {
  createdAt?: { seconds: number };
  active?: boolean;
}

interface Meal {
  active?: boolean;
}

interface Review {
  rating?: number;
}

export default function Dashboard() {
  const [, userLoading, userError] = useAuthState(auth);
  const [userNames, setUserNames] = useState<{ [key: string]: string }>({});
  const [showAllOrders, setShowAllOrders] = useState(false);
  

  
  const allOrdersQuery = query(
    collection(db, "orders"),
    orderBy("createdAt", "desc")
  );
  const [allOrders, allOrdersLoading, allOrdersError] = useCollectionData(allOrdersQuery);
  
  const [usersSnapshot, , usersSnapshotError] = useCollection(query(collection(db, "users")));

  const ordersQuery = query(
    collection(db, "orders"),
    where("status", "==", "received")
  );
  const [orders, ordersLoading, ordersError] = useCollectionData(ordersQuery);

  const mealsQuery = query(collection(db, "meals"), where("active", "==", true));
  const [meals, mealsLoading, mealsError] = useCollectionData(mealsQuery);

  const usersQuery = query(collection(db, "users"));
  const [users, usersLoading, usersError] = useCollectionData(usersQuery);

  const reviewsQuery = query(
    collection(db, "order_reviews"),
    orderBy("createdAt", "desc"),
    limit(100)
  );
  const [reviews] = useCollectionData(reviewsQuery);

  const [restaurantDoc, restaurantLoading, restaurantError] =
    useDocumentData(doc(db, "settings", "restaurant"));
  
  const isRestaurantOpen = restaurantDoc?.isOpen ?? true;
  
  useEffect(() => {
    if (usersSnapshot?.docs) {
      const nameMap: { [key: string]: string } = {};
      usersSnapshot.docs.forEach(doc => {
        const userData = doc.data();
        nameMap[doc.id] = userData.name || userData.displayName || userData.email || 'Unknown Customer';
      });
      setUserNames(nameMap);
    }
  }, [usersSnapshot]);
  
  const getCustomerName = (order: { customerName?: string; name?: string; customer?: string; userId?: string }) => {
    return order.customerName || 
           order.name || 
           order.customer || 
           (order.userId ? userNames[order.userId] : null) ||
           'Unknown Customer';
  };

  const completedOrders = (allOrders as Order[] || []).filter(
    (order: Order) =>
      order.status === "delivered" || order.status === "picked up" || order.status === "completed"
  );

  const getFilteredOrders = (period: string) => {
    return completedOrders.filter((order: Order) => {
      if (!order.createdAt?.seconds) return false;
      const orderDate = moment(order.createdAt.seconds * 1000);
      switch (period) {
        case "today":
          return orderDate.isSame(moment(), "day");
        case "week":
          return orderDate.isSame(moment(), "week");
        case "month":
          return orderDate.isSame(moment(), "month");
        case "year":
          return orderDate.isSame(moment(), "year");
        default:
          return true;
      }
    });
  };

  const todayOrders = getFilteredOrders("today");
  const weekOrders = getFilteredOrders("week");
  const monthOrders = getFilteredOrders("month");
  const yesterdayOrders = completedOrders.filter((order: Order) => {
    if (!order.createdAt?.seconds) return false;
    return moment(order.createdAt.seconds * 1000).isSame(
      moment().subtract(1, "day"),
      "day"
    );
  });

  const todayRevenue = todayOrders.reduce(
    (sum: number, order: Order) => sum + (order.pricing?.total || order.total || 0),
    0
  );
  const weeklyRevenue = weekOrders.reduce(
    (sum: number, order: Order) => sum + (order.pricing?.total || order.total || 0),
    0
  );
  const monthlyRevenue = monthOrders.reduce(
    (sum: number, order: Order) => sum + (order.pricing?.total || order.total || 0),
    0
  );
  const yesterdayRevenue = yesterdayOrders.reduce(
    (sum: number, order: Order) => sum + (order.pricing?.total || order.total || 0),
    0
  );
  const totalRevenue = completedOrders.reduce(
    (sum: number, order: Order) => sum + (order.pricing?.total || order.total || 0),
    0
  );

  const revenueGrowth =
    yesterdayRevenue > 0
      ? ((todayRevenue - yesterdayRevenue) / yesterdayRevenue) * 100
      : 0;
  const avgOrderValue =
    completedOrders.length > 0
      ? totalRevenue / completedOrders.length
      : 0;
  const avgRating =
    reviews && reviews.length > 0
      ? (reviews as Review[]).reduce((sum: number, r: Review) => sum + (r.rating || 0), 0) / reviews.length
      : 0;

  // Responsive order count based on screen size and show more state
  const getOrderCount = useCallback(() => {
    if (showAllOrders) return (allOrders as Order[] || []).length;
    return window.innerWidth >= 1024 ? 8 : window.innerWidth >= 768 ? 6 : 4;
  }, [showAllOrders, allOrders]);
  
  const [orderCount, setOrderCount] = useState(getOrderCount());
  
  useEffect(() => {
    const handleResize = () => {
      if (!showAllOrders) {
        setOrderCount(getOrderCount());
      }
    };
    
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, [showAllOrders, getOrderCount]);
  
  const recentOrders = (allOrders as Order[] || []).slice(0, orderCount);
  const hasMoreOrders = (allOrders as Order[] || []).length > orderCount;

  const isLoading =
    userLoading ||
    ordersLoading ||
    mealsLoading ||
    usersLoading ||
    allOrdersLoading ||
    restaurantLoading;
  const error = userError || ordersError || mealsError || usersError || restaurantError || allOrdersError || usersSnapshotError;

  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-96">
        <Loader />
      </div>
    );
  }

  if (error) {
    // Silently handle permission errors for non-essential data
    if (error.toString().includes('BloomFilter') || 
        error.toString().includes('Missing or insufficient permissions')) {
      // Continue with available data
    } else {
      return (
        <div className="text-red-600 text-center font-semibold bg-red-50 p-4 rounded-xl max-w-6xl mx-auto border border-red-200">
          Error loading data: {String(error)}
        </div>
      );
    }
  }

  return (
    <div className="min-h-[calc(100vh-4rem)] p-6">
      <div className="max-w-7xl mx-auto">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">
            Dashboard Overview
          </h1>
          <p className="text-gray-600">
            Welcome back! Here's what's happening with your restaurant.
          </p>

        </div>

        <div className="mb-6">
          <div
            className={`inline-flex items-center gap-2 px-4 py-2 rounded-full text-sm font-medium ${
              isRestaurantOpen
                ? "bg-green-100 text-green-800 border border-green-200"
                : "bg-red-100 text-red-800 border border-red-200"
            }`}
          >
            <div
              className={`w-2 h-2 rounded-full ${
                isRestaurantOpen ? "bg-green-500" : "bg-red-500"
              }`}
            ></div>
            Restaurant is {isRestaurantOpen ? "Open" : "Closed"}
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <StatCard
            title="Orders to Confirm"
            icon={<ShoppingBag className="text-blue-600" />}
            value={orders?.length || 0}
            link="/orders?filter=received"
            color="blue"
            change={`${orders?.length || 0} awaiting confirmation`}
          />
          <StatCard
            title="Active Meals"
            icon={<Utensils className="text-green-600" />}
            value={meals?.length || 0}
            link="/meals"
            color="green"
            change={`${
              (meals as Meal[] || []).filter((m: Meal) => !m.active).length
            } inactive`}
          />
          <StatCard
            title="Total Customers"
            icon={<Users className="text-purple-600" />}
            value={users?.length || 0}
            link="/users"
            color="purple"
            change={`${
              (users as User[] || []).filter((u: User) =>
                u.createdAt?.seconds && moment(u.createdAt.seconds * 1000).isSame(moment(), "month")
              ).length
            } this month`}
          />
          <StatCard
            title="Avg Rating"
            icon={<Star className="text-amber-600" />}
            value={avgRating.toFixed(1)}
            link="/reviews"
            color="amber"
            change={`${reviews?.length || 0} reviews`}
          />
        </div>

        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-3">
                <Calendar className="text-blue-600" />
                <h3 className="text-sm font-medium text-gray-600">Today's Revenue</h3>
              </div>
              {revenueGrowth !== 0 && (
                <div className={`flex items-center gap-1 text-xs font-medium ${
                  revenueGrowth > 0 ? 'text-green-600' : 'text-red-600'
                }`}>
                  {revenueGrowth > 0 ? <ArrowUp className="w-3 h-3" /> : <ArrowDown className="w-3 h-3" />}
                  {Math.abs(revenueGrowth).toFixed(1)}%
                </div>
              )}
            </div>
            <p className="text-2xl font-bold text-gray-900">${todayRevenue.toFixed(2)}</p>
            <p className="text-xs text-gray-500 mt-1">{todayOrders.length} orders today</p>
          </div>
          
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-3">
                <TrendingUp className="text-green-600" />
                <h3 className="text-sm font-medium text-gray-600">This Week</h3>
              </div>
            </div>
            <p className="text-2xl font-bold text-gray-900">${weeklyRevenue.toFixed(2)}</p>
            <p className="text-xs text-gray-500 mt-1">{weekOrders.length} orders this week</p>
          </div>
          
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-3">
                <Activity className="text-purple-600" />
                <h3 className="text-sm font-medium text-gray-600">This Month</h3>
              </div>
            </div>
            <p className="text-2xl font-bold text-gray-900">${monthlyRevenue.toFixed(2)}</p>
            <p className="text-xs text-gray-500 mt-1">{monthOrders.length} orders this month</p>
          </div>
          
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-3">
                <DollarSign className="text-amber-600" />
                <h3 className="text-sm font-medium text-gray-600">Avg Order Value</h3>
              </div>
            </div>
            <p className="text-2xl font-bold text-gray-900">${avgOrderValue.toFixed(2)}</p>
            <p className="text-xs text-gray-500 mt-1">Across {completedOrders.length} orders</p>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
          {/* Meal Analytics */}
          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <h2 className="text-xl font-semibold text-gray-900 mb-6">Top Performing Meals</h2>
            <div className="space-y-3">
              {(() => {
                // Calculate meal analytics from orders
                const mealStats = new Map();
                completedOrders.forEach((order: Order) => {
                  if (order.items && Array.isArray(order.items)) {
                    order.items.forEach((item: any) => {
                      const mealName = item.name;
                      const quantity = item.quantity || 1;
                      const revenue = quantity * (item.price || 0);
                      
                      if (mealStats.has(mealName)) {
                        const existing = mealStats.get(mealName);
                        mealStats.set(mealName, {
                          ...existing,
                          totalOrders: existing.totalOrders + quantity,
                          totalRevenue: existing.totalRevenue + revenue
                        });
                      } else {
                        mealStats.set(mealName, {
                          name: mealName,
                          totalOrders: quantity,
                          totalRevenue: revenue
                        });
                      }
                    });
                  }
                });
                
                const topMeals = Array.from(mealStats.values())
                  .sort((a, b) => b.totalOrders - a.totalOrders)
                  .slice(0, 5);
                
                return topMeals.length > 0 ? topMeals.map((meal, index) => (
                  <div key={meal.name} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                    <div className="flex items-center gap-3">
                      <span className="w-6 h-6 bg-blue-100 text-blue-600 rounded-full flex items-center justify-center text-sm font-bold">
                        {index + 1}
                      </span>
                      <span className="font-medium text-gray-900">{meal.name}</span>
                    </div>
                    <div className="text-right">
                      <div className="text-sm font-medium text-gray-900">{meal.totalOrders} orders</div>
                      <div className="text-xs text-gray-500">${meal.totalRevenue.toFixed(2)} revenue</div>
                    </div>
                  </div>
                )) : (
                  <div className="text-center py-8 text-gray-500">
                    <TrendingUp className="w-12 h-12 mx-auto mb-2 text-gray-300" />
                    <p>No meal data available</p>
                  </div>
                );
              })()}
            </div>
            <div className="mt-4 pt-4 border-t border-gray-100">
              <Link to="/meals" className="text-blue-600 hover:text-blue-800 text-sm font-medium">
                View detailed analytics →
              </Link>
            </div>
          </div>

          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-xl font-semibold text-gray-900">Recent Orders</h2>
              <Link to="/orders" className="text-blue-600 hover:text-blue-800 text-sm font-medium">
                View all →
              </Link>
            </div>
            <div className="space-y-4">
              {recentOrders.length > 0 ? recentOrders.map((order: Order, index: number) => {
                const isPickup = order.orderType === 'pickup' || order.deliveryMethod === 'pickup' || order.switchedToPickup || (!order.orderType && !order.deliveryMethod);
                const statusColors = {
                  received: "bg-blue-100 text-blue-800",
                  pending: "bg-blue-100 text-blue-800",
                  confirmed: "bg-indigo-100 text-indigo-800",
                  preparing: "bg-yellow-100 text-yellow-800",
                  "ready for pickup": "bg-purple-100 text-purple-800",
                  "picked up": "bg-cyan-100 text-cyan-800",
                  "on the way": "bg-orange-100 text-orange-800",
                  delivered: "bg-green-100 text-green-800",
                  cancelled: "bg-red-100 text-red-800",
                  completed: "bg-emerald-100 text-emerald-800",
                };
                
                return (
                  <div key={order.id || `order-${index}`} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-1">
                        <span className="font-medium text-gray-900">
                          {getCustomerName(order)}
                        </span>
                        <span className="text-xs text-gray-500">
                          {isPickup ? '🏪' : '🚚'}
                        </span>
                      </div>
                      <div className="flex items-center gap-2">
                        <span className={`inline-flex px-2 py-1 text-xs font-medium rounded-full ${
                          statusColors[order.status as keyof typeof statusColors] || "bg-gray-100 text-gray-800"
                        }`}>
                          {order.status === 'received' ? 'Needs Confirmation' : order.status.charAt(0).toUpperCase() + order.status.slice(1)}
                        </span>
                        <span className="text-sm text-gray-500">
                          {(() => {
                            const getStatusTime = () => {
                              switch (order.status) {
                                case 'confirmed':
                                  return order.confirmedTime?.seconds || order.updatedAt?.seconds;
                                case 'preparing':
                                  return order.preparingTime?.seconds || order.updatedAt?.seconds;
                                case 'ready':
                                case 'ready for pickup':
                                  return order.readyTime?.seconds || order.updatedAt?.seconds;
                                case 'picked up':
                                  return order.pickedUpTime?.seconds || order.updatedAt?.seconds;
                                case 'on the way':
                                  return order.updatedAt?.seconds;
                                case 'delivered':
                                  return order.deliveredTime?.seconds || order.updatedAt?.seconds;
                                case 'cancelled':
                                case 'completed':
                                  return order.updatedAt?.seconds;
                                default:
                                  return order.createdAt?.seconds;
                              }
                            };
                            const statusTime = getStatusTime();
                            return statusTime 
                              ? moment(statusTime * 1000).fromNow()
                              : 'Unknown time';
                          })()}
                        </span>
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="font-semibold text-gray-900">
                        ${(order.pricing?.total || order.total || 0).toFixed(2)}
                      </div>
                    </div>
                  </div>
                );
              }) : (
                <div className="text-center py-8 text-gray-500">
                  <Clock className="w-12 h-12 mx-auto mb-2 text-gray-300" />
                  <p>No recent orders</p>
                </div>
              )}
              
              {/* Show More/Less Button */}
              {hasMoreOrders && (
                <div className="text-center pt-4 border-t border-gray-100">
                  <button
                    onClick={() => {
                      setShowAllOrders(!showAllOrders);
                      setOrderCount(showAllOrders ? getOrderCount() : (allOrders as Order[] || []).length);
                    }}
                    className="text-blue-600 hover:text-blue-800 text-sm font-medium transition-colors duration-200"
                  >
                    {showAllOrders ? 'Show Less' : `Show ${(allOrders as Order[] || []).length - orderCount} More`}
                  </button>
                </div>
              )}
            </div>
          </div>

          <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <h2 className="text-xl font-semibold text-gray-900 mb-6">Quick Actions</h2>
            <div className="space-y-4">
              <Link
                to="/orders"
                className="flex items-center gap-3 p-4 bg-blue-50 hover:bg-blue-100 rounded-lg transition-colors duration-200 group"
              >
                <ShoppingBag className="text-blue-600 group-hover:text-blue-700" />
                <div>
                  <div className="font-medium text-gray-900">Manage Orders</div>
                  <div className="text-sm text-gray-600">View and update order status</div>
                </div>
              </Link>
              
              <Link
                to="/meals"
                className="flex items-center gap-3 p-4 bg-green-50 hover:bg-green-100 rounded-lg transition-colors duration-200 group"
              >
                <Utensils className="text-green-600 group-hover:text-green-700" />
                <div>
                  <div className="font-medium text-gray-900">Menu Management</div>
                  <div className="text-sm text-gray-600">Add or edit menu items</div>
                </div>
              </Link>
              
              <Link
                to="/users"
                className="flex items-center gap-3 p-4 bg-purple-50 hover:bg-purple-100 rounded-lg transition-colors duration-200 group"
              >
                <Users className="text-purple-600 group-hover:text-purple-700" />
                <div>
                  <div className="font-medium text-gray-900">Customer Management</div>
                  <div className="text-sm text-gray-600">View customer information</div>
                </div>
              </Link>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

type StatCardProps = {
  title: string;
  icon: React.ReactNode;
  value: number | string;
  link: string;
  color: string;
  change?: string;
};

function StatCard({
  title,
  icon,
  value,
  link,
  color,
  change,
}: StatCardProps) {
  const colorClasses = {
    blue: "bg-blue-50 border-blue-200 text-blue-900",
    green: "bg-green-50 border-green-200 text-green-900",
    purple: "bg-purple-50 border-purple-200 text-purple-900",
    amber: "bg-amber-50 border-amber-200 text-amber-900",
  };

  const linkColors = {
    blue: "text-blue-600 hover:text-blue-800",
    green: "text-green-600 hover:text-green-800",
    purple: "text-purple-600 hover:text-purple-800",
    amber: "text-amber-600 hover:text-amber-800",
  };

  return (
    <div
      className={`${
        colorClasses[color as keyof typeof colorClasses]
      } p-6 rounded-xl shadow-sm hover:shadow-md transition-all duration-200 border`}
    >
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-3">
          {icon}
          <h2 className="text-sm font-medium text-gray-600">{title}</h2>
        </div>
      </div>
      <p className="text-3xl font-bold mb-2">{value}</p>
      {change && <p className="text-xs text-gray-500 mb-2">{change}</p>}
      <Link
        to={link}
        className={`text-sm font-medium ${
          linkColors[color as keyof typeof linkColors]
        } hover:underline transition-colors duration-200`}
      >
        View details →
      </Link>
    </div>
  );
}