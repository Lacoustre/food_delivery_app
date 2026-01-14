import { useState, useMemo } from "react";
import { useCollection } from "react-firebase-hooks/firestore";
import { collection, query, orderBy } from "firebase/firestore";
import { db } from "../firebase";
import Loader from "../components/Loader";
import moment from "moment";
import { TrendingUp, TrendingDown, DollarSign, ShoppingBag, Users, Star } from "lucide-react";

interface Order {
  id: string;
  status: string;
  createdAt?: { seconds: number };
  pricing?: { total?: number };
  total?: number;
  items?: Array<{ name?: string; mealName?: string; quantity?: number }>;
  cartItems?: Array<{ name?: string; mealName?: string; quantity?: number }>;
}

interface User {
  id: string;
  createdAt?: { seconds: number };
}

export default function Analytics() {
  const [timeRange, setTimeRange] = useState("7d");
  
  const [ordersSnapshot, ordersLoading] = useCollection(
    query(collection(db, "orders"), orderBy("createdAt", "desc"))
  );
  
  const [usersSnapshot, usersLoading] = useCollection(
    query(collection(db, "users"), orderBy("createdAt", "desc"))
  );

  const orders: Order[] = ordersSnapshot?.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  })) as Order[] || [];
  
  const users: User[] = usersSnapshot?.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  })) as User[] || [];

  const analytics = useMemo(() => {
    const now = moment();
    const getDateRange = (range: string) => {
      switch (range) {
        case "24h": return now.clone().subtract(1, "day");
        case "7d": return now.clone().subtract(7, "days");
        case "30d": return now.clone().subtract(30, "days");
        case "90d": return now.clone().subtract(90, "days");
        default: return now.clone().subtract(7, "days");
      }
    };

    const startDate = getDateRange(timeRange);
    const prevStartDate = getDateRange(timeRange).subtract(
      timeRange === "24h" ? 1 : timeRange === "7d" ? 7 : timeRange === "30d" ? 30 : 90,
      timeRange === "24h" ? "day" : "days"
    );

    // Filter orders for current and previous periods
    const currentOrders = orders.filter(order => 
      order.createdAt?.seconds && moment(order.createdAt.seconds * 1000).isAfter(startDate)
    );
    
    const prevOrders = orders.filter(order => 
      order.createdAt?.seconds && 
      moment(order.createdAt.seconds * 1000).isBetween(prevStartDate, startDate)
    );

    const completedOrders = currentOrders.filter(order => 
      order.status === 'delivered' || order.status === 'picked up' || order.status === 'completed'
    );
    
    const prevCompletedOrders = prevOrders.filter(order => 
      order.status === 'delivered' || order.status === 'picked up' || order.status === 'completed'
    );

    // Revenue calculations
    const currentRevenue = completedOrders.reduce((sum, order) => 
      sum + (order.pricing?.total || order.total || 0), 0
    );
    
    const prevRevenue = prevCompletedOrders.reduce((sum, order) => 
      sum + (order.pricing?.total || order.total || 0), 0
    );

    const revenueGrowth = prevRevenue > 0 ? ((currentRevenue - prevRevenue) / prevRevenue) * 100 : 0;

    // Order calculations
    const orderGrowth = prevCompletedOrders.length > 0 ? 
      ((completedOrders.length - prevCompletedOrders.length) / prevCompletedOrders.length) * 100 : 0;

    // Customer calculations
    const newCustomers = users.filter(user => 
      user.createdAt?.seconds && moment(user.createdAt.seconds * 1000).isAfter(startDate)
    ).length;
    
    const prevNewCustomers = users.filter(user => 
      user.createdAt?.seconds && 
      moment(user.createdAt.seconds * 1000).isBetween(prevStartDate, startDate)
    ).length;

    const customerGrowth = prevNewCustomers > 0 ? 
      ((newCustomers - prevNewCustomers) / prevNewCustomers) * 100 : 0;

    // Average order value
    const avgOrderValue = completedOrders.length > 0 ? currentRevenue / completedOrders.length : 0;
    const prevAvgOrderValue = prevCompletedOrders.length > 0 ? prevRevenue / prevCompletedOrders.length : 0;
    const avgOrderGrowth = prevAvgOrderValue > 0 ? 
      ((avgOrderValue - prevAvgOrderValue) / prevAvgOrderValue) * 100 : 0;

    // Popular items
    const itemCounts: { [key: string]: number } = {};
    completedOrders.forEach(order => {
      const items = order.items || order.cartItems || [];
      items.forEach(item => {
        const name = item.name || item.mealName || 'Unknown Item';
        itemCounts[name] = (itemCounts[name] || 0) + (item.quantity || 1);
      });
    });

    const popularItems = Object.entries(itemCounts)
      .sort(([,a], [,b]) => b - a)
      .slice(0, 5)
      .map(([name, count]) => ({ name, count }));

    // Daily revenue chart data
    const dailyRevenue = [];
    for (let i = parseInt(timeRange.replace(/\D/g, '')) - 1; i >= 0; i--) {
      const date = now.clone().subtract(i, timeRange === "24h" ? "hours" : "days");
      const dayOrders = completedOrders.filter(order => {
        if (!order.createdAt?.seconds) return false;
        const orderDate = moment(order.createdAt.seconds * 1000);
        return timeRange === "24h" ? 
          orderDate.isSame(date, "hour") : 
          orderDate.isSame(date, "day");
      });
      
      const revenue = dayOrders.reduce((sum, order) => 
        sum + (order.pricing?.total || order.total || 0), 0
      );
      
      dailyRevenue.push({
        date: timeRange === "24h" ? date.format("HH:mm") : date.format("MMM D"),
        revenue,
        orders: dayOrders.length
      });
    }

    return {
      currentRevenue,
      revenueGrowth,
      totalOrders: completedOrders.length,
      orderGrowth,
      newCustomers,
      customerGrowth,
      avgOrderValue,
      avgOrderGrowth,
      popularItems,
      dailyRevenue
    };
  }, [orders, users, timeRange]);

  if (ordersLoading || usersLoading) {
    return (
      <div className="flex justify-center items-center h-[70vh]">
        <Loader />
      </div>
    );
  }

  const StatCard = ({ title, value, change, icon, color }: any) => (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-medium text-gray-600">{title}</p>
          <p className="text-2xl font-bold text-gray-900 mt-2">{value}</p>
          {change !== undefined && (
            <div className={`flex items-center mt-2 text-sm ${
              change >= 0 ? 'text-green-600' : 'text-red-600'
            }`}>
              {change >= 0 ? <TrendingUp className="w-4 h-4 mr-1" /> : <TrendingDown className="w-4 h-4 mr-1" />}
              {Math.abs(change).toFixed(1)}% vs previous period
            </div>
          )}
        </div>
        <div className={`p-3 rounded-full ${color}`}>
          {icon}
        </div>
      </div>
    </div>
  );

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-8">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Analytics</h1>
          <p className="text-gray-600">Track your restaurant's performance and insights.</p>
        </div>
        
        <div className="flex gap-2">
          {["24h", "7d", "30d", "90d"].map((range) => (
            <button
              key={range}
              onClick={() => setTimeRange(range)}
              className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                timeRange === range
                  ? "bg-blue-600 text-white"
                  : "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"
              }`}
            >
              {range === "24h" ? "24 Hours" : range === "7d" ? "7 Days" : range === "30d" ? "30 Days" : "90 Days"}
            </button>
          ))}
        </div>
      </div>

      {/* Key Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <StatCard
          title="Total Revenue"
          value={`$${analytics.currentRevenue.toFixed(2)}`}
          change={analytics.revenueGrowth}
          icon={<DollarSign className="w-6 h-6 text-green-600" />}
          color="bg-green-100"
        />
        <StatCard
          title="Completed Orders"
          value={analytics.totalOrders}
          change={analytics.orderGrowth}
          icon={<ShoppingBag className="w-6 h-6 text-blue-600" />}
          color="bg-blue-100"
        />
        <StatCard
          title="New Customers"
          value={analytics.newCustomers}
          change={analytics.customerGrowth}
          icon={<Users className="w-6 h-6 text-purple-600" />}
          color="bg-purple-100"
        />
        <StatCard
          title="Avg Order Value"
          value={`$${analytics.avgOrderValue.toFixed(2)}`}
          change={analytics.avgOrderGrowth}
          icon={<Star className="w-6 h-6 text-orange-600" />}
          color="bg-orange-100"
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Revenue Chart */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Revenue Trend</h3>
          <div className="h-64 flex items-end justify-between gap-2">
            {analytics.dailyRevenue.map((day, index) => {
              const maxRevenue = Math.max(...analytics.dailyRevenue.map(d => d.revenue));
              const height = maxRevenue > 0 ? (day.revenue / maxRevenue) * 200 : 0;
              
              return (
                <div key={index} className="flex flex-col items-center flex-1">
                  <div
                    className="bg-blue-500 rounded-t w-full min-h-[4px] transition-all duration-300 hover:bg-blue-600"
                    style={{ height: `${height}px` }}
                    title={`${day.date}: $${day.revenue.toFixed(2)}`}
                  />
                  <span className="text-xs text-gray-600 mt-2 transform -rotate-45 origin-left">
                    {day.date}
                  </span>
                </div>
              );
            })}
          </div>
        </div>

        {/* Popular Items */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Popular Items</h3>
          <div className="space-y-4">
            {analytics.popularItems.length === 0 ? (
              <p className="text-gray-500 text-center py-8">No data available</p>
            ) : (
              analytics.popularItems.map((item, index) => {
                const maxCount = analytics.popularItems[0]?.count || 1;
                const percentage = (item.count / maxCount) * 100;
                
                return (
                  <div key={index} className="flex items-center gap-4">
                    <div className="w-8 h-8 bg-orange-100 rounded-full flex items-center justify-center">
                      <span className="text-orange-600 font-medium text-sm">{index + 1}</span>
                    </div>
                    <div className="flex-1">
                      <div className="flex justify-between items-center mb-1">
                        <span className="text-sm font-medium text-gray-900">{item.name}</span>
                        <span className="text-sm text-gray-600">{item.count} sold</span>
                      </div>
                      <div className="w-full bg-gray-200 rounded-full h-2">
                        <div
                          className="bg-orange-500 h-2 rounded-full transition-all duration-300"
                          style={{ width: `${percentage}%` }}
                        />
                      </div>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>
      </div>
    </div>
  );
}