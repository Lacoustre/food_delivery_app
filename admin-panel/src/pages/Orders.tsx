import { useCollection } from "react-firebase-hooks/firestore";
import {
  collection,
  query,
  orderBy,
  updateDoc,
  doc,
  where,
} from "firebase/firestore";
import { db } from "../firebase";
import Loader from "../components/Loader";
import moment from "moment";
import { useState, useEffect } from "react";
import { toast } from "react-toastify";
import { User, Truck } from "lucide-react";

import jsPDF from "jspdf";
import autoTable from "jspdf-autotable";

const statusFilters = ["all", "pending", "confirmed", "preparing", "ready for pickup", "on the way", "delivered", "picked up", "completed", "cancelled"];

type OrderItem = {
  name?: string;
  mealName?: string;
  quantity?: number;
  price?: number;
  mealPrice?: number;
  extras?: Array<{
    name: string;
    price?: number;
  }>;
  instructions?: string;
  specialInstructions?: string;
  notes?: string;
};

type Order = {
  id: string;
  orderId?: string;
  orderNumber?: string;
  customerName?: string;
  name?: string;
  customer?: string;
  userId?: string;
  orderType?: string;
  deliveryMethod?: string;
  switchedToPickup?: boolean;
  driverId?: string;
  driverName?: string;
  delivery?: {
    option?: string;
    fee?: number;
    address?: {
      street?: string;
      city?: string;
      state?: string;
      zipCode?: string;
      coordinates?: {
        latitude: number;
        longitude: number;
      };
    };
  };
  payment?: {
    customerName?: string;
    customerEmail?: string;
    customerPhone?: string;
    method?: string;
    status?: string;
  };
  pricing?: {
    total?: number;
    subtotal?: number;
    tax?: number;
    deliveryFee?: number;
    tip?: number;
  };
  total?: number;
  status?: string;
  deliveryStatus?: string;
  createdAt?: { seconds: number; nanoseconds: number };
  items?: OrderItem[];
  cartItems?: OrderItem[];
};

export default function Orders() {
  const [filter, setFilter] = useState("all");
  const [selectedOrder, setSelectedOrder] = useState<Order | null>(null);
  const [previousStatusMap, setPreviousStatusMap] = useState<{ [key: string]: string }>({});
  const [selectedMonth, setSelectedMonth] = useState(moment().format("YYYY-MM"));
  const [userNames, setUserNames] = useState<{ [key: string]: string }>({});
  const [showDriverModal, setShowDriverModal] = useState(false);
  const [selectedOrderForDriver, setSelectedOrderForDriver] = useState<Order | null>(null);

  // Get available drivers
  const driversQuery = query(
    collection(db, "drivers"),
    where("approvalStatus", "==", "approved")
  );
  const [driversSnapshot] = useCollection(driversQuery);

  const ordersQuery = query(
    collection(db, "orders"),
    orderBy("createdAt", "desc")
  );

  const [snapshot, loading, error] = useCollection(ordersQuery);
  
  // Get users for name lookup
  const [usersSnapshot] = useCollection(query(collection(db, "users")));

  const allOrders: Order[] | undefined = snapshot?.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  })) as Order[] | undefined;
  
  // Client-side filtering
  const orders = allOrders?.filter(order => {
    // Status filter
    if (filter !== "all") {
      const orderStatus = order.deliveryStatus || order.status || 'pending';
      if (orderStatus !== filter) return false;
    }
    
    return true;
  });
  


  // Build user name lookup map
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
  
  // Function to get customer name
  const getCustomerName = (order: Order) => {
    // First try to get from payment object (most reliable)
    if (order.payment?.customerName) {
      return order.payment.customerName;
    }
    
    // Then try other order fields
    if (order.customerName) return order.customerName;
    if (order.name) return order.name;
    if (order.customer) return order.customer;
    
    // Try to get from user lookup
    if (order.userId && userNames[order.userId]) {
      return userNames[order.userId];
    }
    
    // Try to get customer email from payment
    if (order.payment?.customerEmail) {
      return order.payment.customerEmail.split('@')[0];
    }
    
    return 'Unknown Customer';
  };

  const handleAssignDriver = async (orderId: string, driverId: string, driverName: string) => {
    try {
      const orderRef = doc(db, "orders", orderId);
      await updateDoc(orderRef, {
        driverId,
        driverName,
        driverStatus: "assigned",
        assignedAt: new Date(),
        updatedAt: new Date(),
        updatedBy: 'admin'
      });
      
      // The Cloud Function will automatically send notification to driver
      toast.success(`Order assigned to ${driverName}`);
      setShowDriverModal(false);
      setSelectedOrderForDriver(null);
    } catch {
      toast.error("Failed to assign driver");
    }
  };



  const handleStatusChange = async (orderId: string, newStatus: string) => {
    try {
      const orderRef = doc(db, "orders", orderId);
      const order = orders?.find((o) => o.id === orderId);
      const prevStatus = order?.deliveryStatus ?? order?.status ?? "";
      setPreviousStatusMap((prev) => ({ ...prev, [orderId]: prevStatus }));
      
      // Auto-complete delivered/picked up orders
      const finalStatus = (newStatus === "delivered" || newStatus === "picked up") ? "completed" : newStatus;
      
      await updateDoc(orderRef, { 
        deliveryStatus: finalStatus,
        status: finalStatus, // Also update status field for consistency
        updatedAt: new Date(),
        updatedBy: 'admin'
      });
      
      // Show appropriate message based on the status change
      const statusMessages = {
        confirmed: "Order confirmed successfully. Customer will be notified.",
        preparing: "Order marked as preparing. Customer will be notified.",
        "ready for pickup": "Order ready for pickup. Customer will be notified.",
        "on the way": "Order is on the way. Customer will be notified.",
        delivered: "Order marked as delivered and completed. Customer will be notified.",
        "picked up": "Order marked as picked up and completed. Customer will be notified.",
        completed: "Order completed successfully.",
        cancelled: "Order cancelled. Customer will be notified."
      };
      
      const message = statusMessages[finalStatus as keyof typeof statusMessages] || `Order status updated to ${finalStatus}. Customer will be notified.`;
      
      toast.success(message, {
        position: "top-center",
        autoClose: 3000,
      });
    } catch {
      toast.error("Failed to update status", {
        position: "top-center",
        autoClose: 3000,
      });
    }
  };

  const handleUndoStatus = async (orderId: string) => {
    try {
      const prevStatus = previousStatusMap[orderId];
      if (prevStatus) {
        const orderRef = doc(db, "orders", orderId);
        await updateDoc(orderRef, { deliveryStatus: prevStatus });
        toast.success("Undo successful", {
          position: "top-center",
          autoClose: 2000,
        });
      }
    } catch {
      toast.error("Undo failed", {
        position: "top-center",
        autoClose: 3000,
      });
    }
  };

  const exportToPDF = () => {
    const docPdf = new jsPDF();
    const filteredOrders = orders?.filter((order) => {
      if (!order.createdAt || typeof order.createdAt.seconds !== "number") return false;
      const orderDate = moment(order.createdAt.seconds * 1000);
      const isCompleted = order.deliveryStatus === "completed";
      return orderDate.format("YYYY-MM") === selectedMonth && isCompleted;
    });

    // Header with restaurant branding
    docPdf.setFontSize(24);
    docPdf.setTextColor(180, 83, 9); // Amber color
    docPdf.text("Taste of African Cuisine", 14, 20);
    
    docPdf.setFontSize(12);
    docPdf.setTextColor(100);
    docPdf.text("Restaurant Order Report", 14, 30);
    
    // Report details
    docPdf.setFontSize(16);
    docPdf.setTextColor(40);
    docPdf.text(`Completed Orders - ${moment(selectedMonth).format("MMMM YYYY")}`, 14, 45);
    
    docPdf.setFontSize(10);
    docPdf.setTextColor(80);
    docPdf.text(`Generated on: ${moment().format("MMMM D, YYYY [at] h:mm A")}`, 14, 55);
    docPdf.text(`Total Orders: ${filteredOrders?.length || 0}`, 14, 62);
    
    const totalRevenue = (filteredOrders || []).reduce((sum, order) => sum + (order.pricing?.total ?? order.total ?? 0), 0);
    docPdf.text(`Total Revenue: $${totalRevenue.toFixed(2)}`, 14, 69);

    autoTable(docPdf, {
      startY: 80,
      head: [["#", "Order ID", "Customer", "Delivery Type", "Status", "Total ($)", "Date"]],
      body: (filteredOrders || []).map((order, idx) => {
        const isPickup = order.orderType === 'pickup' || order.deliveryMethod === 'pickup' || order.switchedToPickup || (order.delivery?.option?.toLowerCase() === 'pickup') || (!order.orderType && !order.deliveryMethod && !order.delivery?.option);
        return [
          idx + 1,
          order.orderId || order.orderNumber || order.id.substring(0, 8),
          getCustomerName(order),
          isPickup ? "Pickup" : "Delivery",
          (order.deliveryStatus ? order.deliveryStatus.charAt(0).toUpperCase() + order.deliveryStatus.slice(1) : 'Unknown'),
          (order.pricing?.total ?? order.total ?? 0).toFixed(2),
          order.createdAt?.seconds
            ? moment(order.createdAt.seconds * 1000).format("MMM D, YYYY")
            : "—",
        ];
      }) || [],
      headStyles: {
        fillColor: [59, 130, 246], // Blue
        textColor: 255,
        fontSize: 10,
        fontStyle: 'bold',
        halign: "center",
      },
      bodyStyles: {
        fontSize: 9,
        textColor: 50,
        halign: "center",
      },
      alternateRowStyles: {
        fillColor: [248, 250, 252], // Light gray
      },
      margin: { top: 80, bottom: 30, left: 14, right: 14 },
      tableLineColor: [200, 200, 200],
      tableLineWidth: 0.5,
    });
    
    // Footer
    const pageCount = (docPdf as jsPDF & { internal: { getNumberOfPages(): number; pageSize: { height: number } } }).internal.getNumberOfPages();
    docPdf.setFontSize(8);
    docPdf.setTextColor(120);
    docPdf.text(`Page ${pageCount} | Taste of African Cuisine Admin Report`, 14, (docPdf as jsPDF & { internal: { pageSize: { height: number } } }).internal.pageSize.height - 10);

    docPdf.save(`Orders_Report_${moment(selectedMonth).format("MMMM_YYYY")}.pdf`);
  };

  if (loading) {
    return (
      <div className="flex justify-center items-center h-[70vh]">
        <Loader />
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-center text-red-900 font-semibold bg-red-100 p-4 rounded-xl max-w-6xl mx-auto">
        Failed to load orders: {error.message}
      </div>
    );
  }

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4 mb-8">
        <div>
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Orders</h1>
          <p className="text-gray-600">Manage and track all customer orders.</p>
        </div>

        <div className="flex gap-3 items-center">
          <div className="flex items-center gap-2">
            <label className="text-sm font-medium text-gray-700">Month:</label>
            <input
              type="month"
              value={selectedMonth}
              onChange={(e) => setSelectedMonth(e.target.value)}
              className="border border-gray-300 px-3 py-2 rounded-lg text-sm bg-white text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all duration-200"
            />
          </div>
          <button
            onClick={exportToPDF}
            className="bg-green-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-green-700 focus:ring-2 focus:ring-green-500 focus:ring-offset-2 transition-all duration-200 shadow-sm flex items-center gap-2"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            Export Report
          </button>
        </div>
      </div>

      {/* Filter Tabs */}
      <div className="flex gap-2 mb-6 flex-wrap">
        {statusFilters.map((status) => {
          const statusColors = {
            all: filter === status ? "bg-gray-900 text-white" : "bg-white text-gray-700 hover:bg-gray-50",
            pending: filter === status ? "bg-blue-600 text-white" : "bg-white text-gray-700 hover:bg-blue-50",
            confirmed: filter === status ? "bg-indigo-600 text-white" : "bg-white text-gray-700 hover:bg-indigo-50",
            preparing: filter === status ? "bg-yellow-600 text-white" : "bg-white text-gray-700 hover:bg-yellow-50",
            "on the way": filter === status ? "bg-orange-600 text-white" : "bg-white text-gray-700 hover:bg-orange-50",
            delivered: filter === status ? "bg-green-600 text-white" : "bg-white text-gray-700 hover:bg-green-50",
            "ready for pickup": filter === status ? "bg-purple-600 text-white" : "bg-white text-gray-700 hover:bg-purple-50",
            "picked up": filter === status ? "bg-cyan-600 text-white" : "bg-white text-gray-700 hover:bg-cyan-50",
            completed: filter === status ? "bg-emerald-600 text-white" : "bg-white text-gray-700 hover:bg-emerald-50",
            cancelled: filter === status ? "bg-red-600 text-white" : "bg-white text-gray-700 hover:bg-red-50",
          };
          
          return (
            <button
              key={status}
              onClick={() => setFilter(status)}
              className={`px-4 py-2 rounded-lg text-sm font-medium border border-gray-200 transition-all duration-200 ${
                statusColors[status as keyof typeof statusColors] || "bg-white text-gray-700 hover:bg-gray-50"
              }`}
            >
              {status.charAt(0).toUpperCase() + status.slice(1)}
            </button>
          );
        })}
      </div>

      {/* Orders Table */}
      {(orders?.length ?? 0) === 0 ? (
        <div className="bg-white border border-gray-200 rounded-xl p-12 text-center">
          <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <span className="text-2xl">📦</span>
          </div>
          <p className="text-gray-600 text-lg font-medium mb-2">No orders found</p>
          <p className="text-gray-500">Orders will appear here once customers start placing them.</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-200">
            <h2 className="text-lg font-semibold text-gray-900">All Orders ({orders?.length || 0})</h2>
          </div>
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-blue-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-blue-700 uppercase tracking-wider">Order ID</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-blue-700 uppercase tracking-wider">Customer</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-blue-700 uppercase tracking-wider">Total</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-blue-700 uppercase tracking-wider">Status</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-blue-700 uppercase tracking-wider">Date</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-blue-700 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {(orders ?? []).map((order) => {
                  // Check delivery type from multiple fields
                  const isPickup = order.orderType === 'pickup' || 
                                   order.deliveryMethod === 'pickup' || 
                                   order.switchedToPickup || 
                                   (order.delivery?.option?.toLowerCase() === 'pickup') ||
                                   (!order.orderType && !order.deliveryMethod && !order.delivery?.option);
                  const statusColors = {
                    pending: "bg-blue-100 text-blue-800",
                    confirmed: "bg-indigo-100 text-indigo-800",
                    preparing: "bg-yellow-100 text-yellow-800",
                    "ready for pickup": "bg-purple-100 text-purple-800",
                    "on the way": "bg-orange-100 text-orange-800",
                    delivered: "bg-green-100 text-green-800",
                    "picked up": "bg-cyan-100 text-cyan-800",
                    completed: "bg-emerald-100 text-emerald-800",
                    cancelled: "bg-red-100 text-red-800",
                  };
                  
                  return (
                    <tr key={order.id} className="hover:bg-gray-50 transition-colors duration-150">
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-mono text-gray-900">
                        {order.orderId || order.id}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        <div>
                          <div>{getCustomerName(order)}</div>
                          <div className="text-xs text-gray-500">
                            {isPickup ? '🏪 Pickup' : '🚚 Delivery'}
                            {order.switchedToPickup && (
                              <span className="ml-1 text-orange-600 font-medium">(Switched)</span>
                            )}
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                        ${(order.pricing?.total ?? order.total ?? 0).toFixed(2)}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <select
                          value={order.deliveryStatus || order.status || 'pending'}
                          onChange={(e) => handleStatusChange(order.id, e.target.value)}
                          className={`text-sm font-medium px-3 py-2 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 ${statusColors[(order.deliveryStatus || order.status || 'pending') as keyof typeof statusColors] || "bg-gray-100 text-gray-800"}`}
                        >
                          {(() => {
                            // Use the same logic for status dropdown
                            const isPickup = order.orderType === 'pickup' || 
                                             order.deliveryMethod === 'pickup' || 
                                             order.switchedToPickup || 
                                             (order.delivery?.option?.toLowerCase() === 'pickup') ||
                                             (!order.orderType && !order.deliveryMethod && !order.delivery?.option);

                            
                            const currentStatus = order.deliveryStatus || order.status || 'pending';
                            
                            // If order is still 'pending', only allow confirming it
                            if (currentStatus === 'pending') {
                              return (
                                <>
                                  <option key="pending" value="pending">📥 Needs Confirmation</option>
                                  <option key="confirmed" value="confirmed">✅ Confirm Order</option>
                                  <option key="cancelled" value="cancelled">❌ Cancel</option>
                                </>
                              );
                            }
                            
                            // Show all possible statuses based on order type
                            const pickupStatuses = ["pending", "confirmed", "preparing", "ready for pickup", "picked up", "completed", "cancelled"];
                            const deliveryStatuses = ["pending", "confirmed", "preparing", "on the way", "delivered", "completed", "cancelled"];
                            const statuses = isPickup ? pickupStatuses : deliveryStatuses;
                            
                            return statuses.map((status) => {
                              const icons = {
                                confirmed: '✅ ',
                                preparing: '👨‍🍳 ',
                                'ready for pickup': '🔔 ',
                                'on the way': '🚚 ',
                                delivered: '📦 ',
                                'picked up': '✅ ',
                                cancelled: '❌ '
                              };
                              return (
                                <option key={status} value={status}>
                                  {icons[status as keyof typeof icons] || ''}{status.charAt(0).toUpperCase() + status.slice(1)}
                                </option>
                              );
                            });
                          })()}
                        </select>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {order.createdAt?.seconds
                          ? moment(order.createdAt.seconds * 1000).format("MMM D, YYYY")
                          : "—"}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-3">
                        <button
                          onClick={() => setSelectedOrder(order)}
                          className="text-blue-600 hover:text-blue-800 transition-colors duration-150"
                        >
                          View
                        </button>
                        {!order.driverId && (order.deliveryStatus === 'confirmed' || order.deliveryStatus === 'preparing') && !isPickup && (
                          <button
                            onClick={() => {
                              setSelectedOrderForDriver(order);
                              setShowDriverModal(true);
                            }}
                            className="text-green-600 hover:text-green-800 transition-colors duration-150 flex items-center gap-1"
                          >
                            <Truck className="w-4 h-4" />
                            Assign Driver
                          </button>
                        )}
                        {order.driverId && (
                          <span className="text-xs text-gray-500 flex items-center gap-1">
                            <User className="w-3 h-3" />
                            {order.driverName || 'Driver Assigned'}
                          </span>
                        )}
                        {previousStatusMap[order.id] && (
                          <button
                            onClick={() => handleUndoStatus(order.id)}
                            className="text-orange-600 hover:text-orange-800 transition-colors duration-150"
                          >
                            Undo
                          </button>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Details Modal */}
      {selectedOrder && (
        <div className="fixed inset-0 bg-black/50 z-50 flex justify-center items-center backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-2xl p-8 w-full max-w-lg border border-gray-200 m-4">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-xl font-bold text-gray-900">Order Details</h2>
              <button
                onClick={() => setSelectedOrder(null)}
                className="text-gray-400 hover:text-gray-600 transition-colors"
              >
                <span className="sr-only">Close</span>
                <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-sm font-medium text-gray-500">Order ID</p>
                  <p className="text-sm text-gray-900 font-mono">{selectedOrder.orderId || selectedOrder.id}</p>
                </div>
                <div>
                  <p className="text-sm font-medium text-gray-500">Customer</p>
                  <p className="text-sm text-gray-900">{getCustomerName(selectedOrder)}</p>
                </div>
              </div>
              
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-sm font-medium text-gray-500">Total</p>
                  <p className="text-lg font-bold text-gray-900">${(selectedOrder.pricing?.total ?? selectedOrder.total ?? 0).toFixed(2)}</p>
                </div>
                <div>
                  <p className="text-sm font-medium text-gray-500">Status</p>
                  <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${(
                    {
                      pending: 'bg-blue-100 text-blue-800',
                      confirmed: 'bg-indigo-100 text-indigo-800',
                      preparing: 'bg-yellow-100 text-yellow-800',
                      'ready for pickup': 'bg-purple-100 text-purple-800',
                      'on the way': 'bg-orange-100 text-orange-800',
                      delivered: 'bg-green-100 text-green-800',
                      'picked up': 'bg-cyan-100 text-cyan-800',
                      completed: 'bg-emerald-100 text-emerald-800',
                      cancelled: 'bg-red-100 text-red-800',
                    }[(selectedOrder.deliveryStatus || 'pending')] || 'bg-gray-100 text-gray-800'
                  )}`}>
                    {(selectedOrder.deliveryStatus || 'pending') === 'pending' ? 'Needs Confirmation' : (selectedOrder.deliveryStatus || 'pending') === 'cancelled' ? '❌ Cancelled' : (selectedOrder.deliveryStatus || 'pending') === 'completed' ? '✅ Completed' : (selectedOrder.deliveryStatus || 'pending').charAt(0).toUpperCase() + (selectedOrder.deliveryStatus || 'pending').slice(1)}
                  </span>
                </div>
              </div>
              
              <div>
                <p className="text-sm font-medium text-gray-500">Date</p>
                <p className="text-sm text-gray-900">
                  {selectedOrder.createdAt?.seconds
                    ? moment(selectedOrder.createdAt.seconds * 1000).format("MMMM D, YYYY, h:mm A")
                    : "—"}
                </p>
              </div>
              
              {/* Ordered Items */}
              {(selectedOrder.items || selectedOrder.cartItems) && (
                <div className="border-t border-gray-200 pt-4">
                  <p className="text-sm font-medium text-gray-500 mb-3">Ordered Items</p>
                  <div className="space-y-3">
                    {(selectedOrder.items || selectedOrder.cartItems || []).map((item: OrderItem, index: number) => (
                      <div key={index} className="p-4 bg-gray-50 rounded-lg border border-gray-200">
                        <div className="flex justify-between items-start mb-2">
                          <div className="flex-1">
                            <p className="text-sm font-medium text-gray-900">{item.name || item.mealName || 'Unknown Item'}</p>
                            <p className="text-xs text-gray-600 mt-1">Quantity: {item.quantity || 1}</p>
                          </div>
                          <div className="text-sm font-medium text-gray-900">
                            ${((item.price || item.mealPrice || 0) * (item.quantity || 1)).toFixed(2)}
                          </div>
                        </div>
                        
                        {/* Extras/Add-ons */}
                        {item.extras && item.extras.length > 0 && (
                          <div className="mt-3 pt-3 border-t border-gray-300">
                            <p className="text-xs font-medium text-gray-700 mb-2">Extras:</p>
                            <div className="space-y-1">
                              {item.extras.map((extra, extraIndex: number) => (
                                <div key={extraIndex} className="flex justify-between items-center text-xs">
                                  <span className="text-gray-600">• {extra.name}</span>
                                  <span className="text-gray-700 font-medium">+${extra.price?.toFixed(2) || '0.00'}</span>
                                </div>
                              ))}
                            </div>
                          </div>
                        )}
                        
                        {/* Special Instructions */}
                        {(item.instructions || item.specialInstructions) && (
                          <div className="mt-3 pt-3 border-t border-gray-300">
                            <p className="text-xs font-medium text-gray-700 mb-1">Special Instructions:</p>
                            <div className="text-xs text-gray-600 bg-yellow-50 p-2 rounded border border-yellow-200">
                              📝 {item.instructions || item.specialInstructions}
                            </div>
                          </div>
                        )}
                        
                        {/* Notes */}
                        {item.notes && (
                          <div className="mt-3 pt-3 border-t border-gray-300">
                            <p className="text-xs font-medium text-gray-700 mb-1">Notes:</p>
                            <div className="text-xs text-gray-600 italic">
                              {item.notes}
                            </div>
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                </div>
              )}
              
              {selectedOrder.pricing && (
                <div className="border-t border-gray-200 pt-4">
                  <p className="text-sm font-medium text-gray-500 mb-3">Price Breakdown</p>
                  <div className="space-y-2 text-sm">
                    <div className="flex justify-between">
                      <span className="text-gray-600">Subtotal:</span>
                      <span className="text-gray-900">${(selectedOrder.pricing.subtotal ?? 0).toFixed(2)}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Tax:</span>
                      <span className="text-gray-900">${(selectedOrder.pricing.tax ?? 0).toFixed(2)}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Delivery Fee:</span>
                      <span className="text-gray-900">${(selectedOrder.pricing.deliveryFee ?? 0).toFixed(2)}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Tip:</span>
                      <span className="text-gray-900">${(selectedOrder.pricing.tip ?? 0).toFixed(2)}</span>
                    </div>
                  </div>
                </div>
              )}
            </div>
            
            <div className="flex justify-end mt-8">
              <button
                onClick={() => setSelectedOrder(null)}
                className="px-4 py-2 bg-gray-100 text-gray-900 rounded-lg hover:bg-gray-200 font-medium transition-colors duration-200"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Driver Assignment Modal */}
      {showDriverModal && selectedOrderForDriver && (
        <div className="fixed inset-0 bg-black/50 z-50 flex justify-center items-center backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-2xl p-8 w-full max-w-md border border-gray-200 m-4">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-xl font-bold text-gray-900">Assign Driver</h2>
              <button
                onClick={() => {
                  setShowDriverModal(false);
                  setSelectedOrderForDriver(null);
                }}
                className="text-gray-400 hover:text-gray-600 transition-colors"
              >
                <span className="sr-only">Close</span>
                <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            
            <div className="mb-4">
              <p className="text-sm text-gray-600 mb-2">Order: {selectedOrderForDriver.orderId || selectedOrderForDriver.id}</p>
              <p className="text-sm text-gray-600">Customer: {getCustomerName(selectedOrderForDriver)}</p>
            </div>
            
            <div className="space-y-3">
              <h3 className="text-sm font-medium text-gray-700">Available Drivers:</h3>
              {driversSnapshot?.docs.length === 0 ? (
                <p className="text-sm text-gray-500 py-4 text-center">No available drivers found</p>
              ) : (
                driversSnapshot?.docs.map((driverDoc) => {
                  const driver = driverDoc.data();
                  const isOnline = driver.isActive;
                  return (
                    <button
                      key={driverDoc.id}
                      onClick={() => handleAssignDriver(
                        selectedOrderForDriver.id,
                        driverDoc.id,
                        driver.name || driver.email || 'Unknown Driver'
                      )}
                      disabled={!isOnline}
                      className={`w-full p-3 rounded-lg border text-left transition-colors ${
                        isOnline
                          ? 'border-green-200 bg-green-50 hover:bg-green-100 text-green-900'
                          : 'border-gray-200 bg-gray-50 text-gray-400 cursor-not-allowed'
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="font-medium">{driver.name || driver.email || 'Unknown Driver'}</p>
                          <p className="text-xs text-gray-500">{driver.email}</p>
                        </div>
                        <div className="flex items-center gap-2">
                          <div className={`w-2 h-2 rounded-full ${
                            isOnline ? 'bg-green-500' : 'bg-gray-400'
                          }`} />
                          <span className="text-xs">{isOnline ? 'Online' : 'Offline'}</span>
                        </div>
                      </div>
                    </button>
                  );
                })
              )}
            </div>
            
            <div className="flex justify-end mt-6">
              <button
                onClick={() => {
                  setShowDriverModal(false);
                  setSelectedOrderForDriver(null);
                }}
                className="px-4 py-2 bg-gray-100 text-gray-900 rounded-lg hover:bg-gray-200 font-medium transition-colors duration-200"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}