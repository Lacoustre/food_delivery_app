import { supabase } from "../lib/supabase";
import Loader from "../components/Loader";
import moment from "moment";
import { useState, useEffect, useCallback } from "react";
import { toast } from "react-toastify";
import { User, Truck } from "lucide-react";

import jsPDF from "jspdf";
import autoTable from "jspdf-autotable";
import { netPaid } from "../lib/money";

const statusFilters = ["all", "pending", "confirmed", "preparing", "ready for pickup", "on the way", "delivered", "picked up", "completed", "cancelled"];

type OrderItemRow = {
  id: string;
  meal_id: string;
  name: string | null;
  quantity: number;
  unit_price: number;
};

type ProfileRow = {
  name: string | null;
  email: string | null;
  phone: string | null;
};

type Order = {
  id: string;
  order_number: string | null;
  user_id: string;
  order_type: "delivery" | "pickup" | null;
  status: string;
  subtotal: number;
  delivery_fee: number;
  tax: number;
  total: number;
  delivery_address: string | null;
  payment_method: "card" | "cash" | null;
  driver_id: string | null;
  driver_name: string | null;
  driver_status: string | null;
  delivery_provider: string | null;
  uber_delivery_id: string | null;
  uber_tracking_url: string | null;
  uber_delivery_status: string | null;
  refund_id: string | null;
  refund_amount: number | null;
  created_at: string;
  order_items: OrderItemRow[];
  profiles: ProfileRow | ProfileRow[] | null;
};

export default function Orders() {
  const [filter, setFilter] = useState("all");
  const [selectedOrder, setSelectedOrder] = useState<Order | null>(null);
  const [previousStatusMap, setPreviousStatusMap] = useState<{ [key: string]: string }>({});
  const [selectedMonth, setSelectedMonth] = useState(moment().format("YYYY-MM"));

  const [allOrders, setAllOrders] = useState<Order[] | undefined>(undefined);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const fetchOrders = useCallback(async () => {
    const { data, error } = await supabase
      .from("orders")
      .select("*, order_items(*), profiles!user_id(name, email, phone)")
      .order("created_at", { ascending: false });

    if (error) {
      setError(new Error(error.message));
    } else {
      setError(null);
      setAllOrders(data as Order[]);
    }
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchOrders();

    // Realtime — any change to orders refetches the full list, mirroring
    // how the previous Firestore onSnapshot always delivered a fresh
    // snapshot rather than a manual patch.
    const channel = supabase
      .channel("orders-changes")
      .on("postgres_changes", { event: "*", schema: "public", table: "orders" }, () => {
        fetchOrders();
      })
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [fetchOrders]);

  // Client-side filtering
  const orders = allOrders?.filter((order) => {
    if (filter !== "all" && order.status !== filter) return false;
    return true;
  });

  const getCustomer = (order: Order): ProfileRow | null => {
    if (!order.profiles) return null;
    return Array.isArray(order.profiles) ? order.profiles[0] ?? null : order.profiles;
  };

  const getCustomerName = (order: Order) => {
    const customer = getCustomer(order);
    if (customer?.name) return customer.name;
    if (customer?.email) return customer.email.split("@")[0];
    return "Unknown Customer";
  };

  /**
   * Refunds a cancelled order through the customer site, which is the only
   * side holding the Stripe secret key. The route is admin-only and refuses a
   * second refund, so a double click cannot send the money twice.
   */
  const refundCancelledOrder = async (orderId: string) => {
    const base = import.meta.env.VITE_WEBAPP_URL;
    if (!base) {
      toast.warning("Order cancelled, but VITE_WEBAPP_URL is not set — refund it in Stripe by hand.", {
        position: "top-center",
        autoClose: 8000
      });
      return;
    }

    try {
      const { data: { session } } = await supabase.auth.getSession();
      const res = await fetch(`${base}/api/refund`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${session?.access_token ?? ""}`
        },
        body: JSON.stringify({ orderId })
      });
      const body = await res.json().catch(() => null);

      if (res.ok) {
        toast.success(`Order cancelled and $${Number(body.refundAmount).toFixed(2)} refunded.`, {
          position: "top-center",
          autoClose: 5000
        });
        return;
      }

      // The order is already cancelled at this point. Say exactly what did not
      // happen, so nobody assumes the customer has their money back.
      toast.warning(`Order cancelled, but the refund did not go through: ${body?.error ?? res.status}`, {
        position: "top-center",
        autoClose: 10000
      });
    } catch {
      toast.warning("Order cancelled, but the refund could not be reached. Refund it in Stripe.", {
        position: "top-center",
        autoClose: 10000
      });
    }
  };

  /**
   * Takes the cancelled order's ticket off the POS.
   *
   * Cancelling used to set a status and move the money while telling Clover
   * nothing, so the kitchen ticket stayed open and staff could cook food for
   * an order that no longer existed.
   *
   * A ticket already marked paid cannot be removed through the API — that has
   * to happen on the terminal — so the route says so and this reports it
   * rather than pretending it worked.
   */
  const clearCloverTicket = async (orderId: string): Promise<string | null> => {
    const base = import.meta.env.VITE_WEBAPP_URL;
    if (!base) return "VITE_WEBAPP_URL is not set";
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const res = await fetch(`${base}/api/cancel-clover-order`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${session?.access_token ?? ""}`
        },
        body: JSON.stringify({ orderId })
      });
      if (res.ok) return null;
      const body = await res.json().catch(() => null);
      return body?.needsManualVoid
        ? `void ticket ${body.cloverOrderId} on the Clover terminal`
        : body?.error ?? `HTTP ${res.status}`;
    } catch {
      return "could not reach the site";
    }
  };

  /**
   * Calls a courier, now that the food exists.
   *
   * Uber used to be dispatched the moment the customer paid, so a driver was
   * sent to collect food nobody had started. On order #1008 the courier
   * arrived mid-preparation and the delivery had to be cancelled and the fee
   * refunded. Dispatch now happens here, when staff mark the order ready.
   *
   * Safe to call twice: the route refuses to send a second courier to an order
   * that already has one.
   */
  const dispatchCourier = async (orderId: string): Promise<string | null> => {
    const base = import.meta.env.VITE_WEBAPP_URL;
    if (!base) return "VITE_WEBAPP_URL is not set";
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const res = await fetch(`${base}/api/dispatch-delivery`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${session?.access_token ?? ""}`
        },
        body: JSON.stringify({ orderId })
      });
      const body = await res.json().catch(() => null);
      if (res.ok) return null;
      return body?.error ?? `HTTP ${res.status}`;
    } catch {
      return "could not reach the site";
    }
  };

  /**
   * Tells the customer their order moved on. The toasts used to claim
   * "Customer will be notified" while nothing was sent at all — a customer got
   * a confirmation when they ordered and then silence, including when a pickup
   * order was sitting ready on the counter.
   *
   * Clover cannot do this: its orders only carry open/locked/paid, a payment
   * lifecycle with no notion of food being ready. So it has to happen here.
   */
  const notifyCustomer = async (orderId: string): Promise<string | null> => {
    const base = import.meta.env.VITE_WEBAPP_URL;
    if (!base) return "VITE_WEBAPP_URL is not set";
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const res = await fetch(`${base}/api/notify-order-status`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${session?.access_token ?? ""}`
        },
        body: JSON.stringify({ orderId })
      });
      if (res.ok) return null;
      const body = await res.json().catch(() => null);
      return body?.error ?? `HTTP ${res.status}`;
    } catch {
      return "could not reach the site";
    }
  };

  const handleStatusChange = async (orderId: string, newStatus: string) => {
    try {
      const order = orders?.find((o) => o.id === orderId);
      const prevStatus = order?.status ?? "";
      setPreviousStatusMap((prev) => ({ ...prev, [orderId]: prevStatus }));

      // Auto-complete delivered/picked up orders
      const finalStatus = newStatus === "delivered" || newStatus === "picked up" ? "completed" : newStatus;

      const { error } = await supabase
        .from("orders")
        .update({ status: finalStatus, updated_at: new Date().toISOString() })
        .eq("id", orderId);
      if (error) throw error;

      // Cancelling has to move the money, not just the status. Without this
      // the customer was emailed "you will receive a refund shortly" while
      // their card stayed charged until somebody remembered to do it by hand.
      if (finalStatus === "cancelled") {
        // Money first: it is the part the customer notices.
        await refundCancelledOrder(orderId);

        const ticketProblem = await clearCloverTicket(orderId);
        if (ticketProblem) {
          toast.warning(`Kitchen ticket still open in Clover — ${ticketProblem}.`, {
            position: "top-center",
            autoClose: 10000
          });
        }

        // "cancelled" is not in worthTelling below, and this branch returns
        // before reaching it, so a cancelled customer was never told anything
        // — even though the email for it already existed.
        const notifyProblem = await notifyCustomer(orderId);
        if (notifyProblem) {
          toast.warning(`The customer was NOT emailed about the cancellation: ${notifyProblem}`, {
            position: "top-center",
            autoClose: 8000
          });
        }
        return;
      }

      // These used to end "Customer will be notified", which was not true —
      // nothing sends anything on a status change yet.
      const statusMessages = {
        confirmed: "Order confirmed.",
        preparing: "Order marked as preparing.",
        "ready for pickup": "Order marked ready for pickup.",
        "on the way": "Order marked as on the way.",
        delivered: "Order marked as delivered and completed.",
        "picked up": "Order marked as picked up and completed.",
        completed: "Order completed."
      };

      const message = statusMessages[finalStatus as keyof typeof statusMessages] || `Order status updated to ${finalStatus}.`;

      // Ready means the food exists, which is the only moment it makes sense
      // to call a courier. The route ignores pickup orders and refuses to send
      // a second driver to an order that already has one.
      if (finalStatus === "ready for pickup" && order?.order_type === "delivery") {
        const problem = await dispatchCourier(orderId);
        if (problem) {
          toast.warning(`Order marked ready, but NO courier was called: ${problem}`, {
            position: "top-center",
            autoClose: 10000
          });
        } else {
          toast.success("Order marked ready. A courier is on the way to collect.", {
            position: "top-center",
            autoClose: 5000
          });
        }
      }

      // Only the states a customer cares about. Nobody needs an email saying
      // their order went from "pending" to "confirmed" thirty seconds apart.
      const worthTelling = ["preparing", "ready for pickup", "on the way", "delivered", "picked up"];

      if (worthTelling.includes(finalStatus)) {
        const problem = await notifyCustomer(orderId);
        if (problem) {
          toast.warning(`${message} The customer was NOT emailed: ${problem}`, {
            position: "top-center",
            autoClose: 8000
          });
        } else {
          toast.success(`${message} Customer emailed.`, {
            position: "top-center",
            autoClose: 3000
          });
        }
        return;
      }

      toast.success(message, {
        position: "top-center",
        autoClose: 3000
      });
    } catch {
      toast.error("Failed to update status", {
        position: "top-center",
        autoClose: 3000
      });
    }
  };

  const handleUndoStatus = async (orderId: string) => {
    try {
      const prevStatus = previousStatusMap[orderId];
      if (prevStatus) {
        const { error } = await supabase.from("orders").update({ status: prevStatus }).eq("id", orderId);
        if (error) throw error;
        toast.success("Undo successful", {
          position: "top-center",
          autoClose: 2000
        });
      }
    } catch {
      toast.error("Undo failed", {
        position: "top-center",
        autoClose: 3000
      });
    }
  };

  const exportToPDF = () => {
    const docPdf = new jsPDF();
    const filteredOrders = orders?.filter((order) => {
      const orderDate = moment(order.created_at);
      const isCompleted = order.status === "completed";
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

    const totalRevenue = (filteredOrders || []).reduce((sum, order) => sum + netPaid(order), 0);
    const totalRefunded = (filteredOrders || []).reduce((sum, order) => sum + Number(order.refund_amount ?? 0), 0);
    docPdf.text(`Total Revenue: $${totalRevenue.toFixed(2)}`, 14, 69);
    if (totalRefunded > 0) {
      docPdf.text(`(after $${totalRefunded.toFixed(2)} refunded)`, 14, 76);
    }

    autoTable(docPdf, {
      startY: 80,
      head: [["#", "Order ID", "Customer", "Delivery Type", "Status", "Total ($)", "Date"]],
      body: (filteredOrders || []).map((order, idx) => {
        const isPickup = order.order_type === "pickup";
        return [
          idx + 1,
          order.order_number || order.id.substring(0, 8),
          getCustomerName(order),
          isPickup ? "Pickup" : "Delivery",
          order.status ? order.status.charAt(0).toUpperCase() + order.status.slice(1) : "Unknown",
          netPaid(order).toFixed(2),
          order.created_at ? moment(order.created_at).format("MMM D, YYYY") : "—"
        ];
      }) || [],
      headStyles: {
        fillColor: [59, 130, 246], // Blue
        textColor: 255,
        fontSize: 10,
        fontStyle: "bold",
        halign: "center"
      },
      bodyStyles: {
        fontSize: 9,
        textColor: 50,
        halign: "center"
      },
      alternateRowStyles: {
        fillColor: [248, 250, 252] // Light gray
      },
      margin: { top: 80, bottom: 30, left: 14, right: 14 },
      tableLineColor: [200, 200, 200],
      tableLineWidth: 0.5
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
            cancelled: filter === status ? "bg-red-600 text-white" : "bg-white text-gray-700 hover:bg-red-50"
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
                  const isPickup = order.order_type === "pickup";
                  const statusColors = {
                    pending: "bg-blue-100 text-blue-800",
                    confirmed: "bg-indigo-100 text-indigo-800",
                    preparing: "bg-yellow-100 text-yellow-800",
                    "ready for pickup": "bg-purple-100 text-purple-800",
                    "on the way": "bg-orange-100 text-orange-800",
                    delivered: "bg-green-100 text-green-800",
                    "picked up": "bg-cyan-100 text-cyan-800",
                    completed: "bg-emerald-100 text-emerald-800",
                    cancelled: "bg-red-100 text-red-800"
                  };

                  return (
                    <tr key={order.id} className="hover:bg-gray-50 transition-colors duration-150">
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-mono text-gray-900">
                        {order.order_number || order.id}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        <div>
                          <div>{getCustomerName(order)}</div>
                          <div className="text-xs text-gray-500">{isPickup ? "🏪 Pickup" : "🚚 Delivery"}</div>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                        ${netPaid(order).toFixed(2)}
                        {order.refund_amount ? (
                          <div className="text-xs font-normal text-amber-700">
                            ${Number(order.refund_amount).toFixed(2)} refunded of ${Number(order.total).toFixed(2)}
                          </div>
                        ) : null}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <select
                          value={order.status || "pending"}
                          onChange={(e) => handleStatusChange(order.id, e.target.value)}
                          className={`text-sm font-medium px-3 py-2 rounded-lg border border-gray-300 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 ${statusColors[(order.status || "pending") as keyof typeof statusColors] || "bg-gray-100 text-gray-800"}`}
                        >
                          {(() => {
                            const currentStatus = order.status || "pending";

                            if (currentStatus === "pending") {
                              return (
                                <>
                                  <option key="pending" value="pending">📥 Needs Confirmation</option>
                                  <option key="confirmed" value="confirmed">✅ Confirm Order</option>
                                  <option key="cancelled" value="cancelled">❌ Cancel</option>
                                </>
                              );
                            }

                            const pickupStatuses = ["pending", "confirmed", "preparing", "ready for pickup", "picked up", "completed", "cancelled"];
                            const deliveryStatuses = ["pending", "confirmed", "preparing", "on the way", "delivered", "completed", "cancelled"];
                            const statuses = isPickup ? pickupStatuses : deliveryStatuses;

                            return statuses.map((status) => {
                              const icons = {
                                confirmed: "✅ ",
                                preparing: "👨‍🍳 ",
                                "ready for pickup": "🔔 ",
                                "on the way": "🚚 ",
                                delivered: "📦 ",
                                "picked up": "✅ ",
                                cancelled: "❌ "
                              };
                              return (
                                <option key={status} value={status}>
                                  {icons[status as keyof typeof icons] || ""}{status.charAt(0).toUpperCase() + status.slice(1)}
                                </option>
                              );
                            });
                          })()}
                        </select>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {order.created_at ? moment(order.created_at).format("MMM D, YYYY") : "—"}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-3">
                        <button
                          onClick={() => setSelectedOrder(order)}
                          className="text-blue-600 hover:text-blue-800 transition-colors duration-150"
                        >
                          View
                        </button>
                        {/* Delivery is handled by Uber Direct — dispatched automatically
                            at order confirmation; couriers are no longer assigned here. */}
                        {order.delivery_provider === "uber_direct" && (
                          order.uber_tracking_url ? (
                            <a
                              href={order.uber_tracking_url}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="text-green-600 hover:text-green-800 transition-colors duration-150 inline-flex items-center gap-1"
                            >
                              <Truck className="w-4 h-4" />
                              {order.uber_delivery_status || "dispatched"}
                            </a>
                          ) : (
                            <span className="text-xs text-gray-500 inline-flex items-center gap-1">
                              <Truck className="w-3 h-3" />
                              {order.uber_delivery_status || "dispatched"}
                            </span>
                          )
                        )}
                        {!order.delivery_provider && !isPickup && (order.status === "confirmed" || order.status === "preparing") && (
                          <span className="text-xs text-amber-600 inline-flex items-center gap-1" title="Uber dispatch didn't run for this order — arrange delivery manually">
                            <Truck className="w-3 h-3" />
                            not dispatched
                          </span>
                        )}
                        {order.driver_name && (
                          <span className="text-xs text-gray-500 flex items-center gap-1">
                            <User className="w-3 h-3" />
                            {order.driver_name}
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
                  <p className="text-sm text-gray-900 font-mono">{selectedOrder.order_number || selectedOrder.id}</p>
                </div>
                <div>
                  <p className="text-sm font-medium text-gray-500">Customer</p>
                  <p className="text-sm text-gray-900">{getCustomerName(selectedOrder)}</p>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-sm font-medium text-gray-500">Total</p>
                  <p className="text-lg font-bold text-gray-900">${netPaid(selectedOrder).toFixed(2)}</p>
                  {selectedOrder.refund_amount ? (
                    <p className="text-xs text-amber-700">
                      ${Number(selectedOrder.refund_amount).toFixed(2)} refunded of $
                      {Number(selectedOrder.total).toFixed(2)}
                    </p>
                  ) : null}
                </div>
                <div>
                  <p className="text-sm font-medium text-gray-500">Status</p>
                  <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${(
                    {
                      pending: "bg-blue-100 text-blue-800",
                      confirmed: "bg-indigo-100 text-indigo-800",
                      preparing: "bg-yellow-100 text-yellow-800",
                      "ready for pickup": "bg-purple-100 text-purple-800",
                      "on the way": "bg-orange-100 text-orange-800",
                      delivered: "bg-green-100 text-green-800",
                      "picked up": "bg-cyan-100 text-cyan-800",
                      completed: "bg-emerald-100 text-emerald-800",
                      cancelled: "bg-red-100 text-red-800"
                    }[selectedOrder.status || "pending"] || "bg-gray-100 text-gray-800"
                  )}`}>
                    {(selectedOrder.status || "pending") === "pending" ? "Needs Confirmation" : (selectedOrder.status || "pending") === "cancelled" ? "❌ Cancelled" : (selectedOrder.status || "pending") === "completed" ? "✅ Completed" : (selectedOrder.status || "pending").charAt(0).toUpperCase() + (selectedOrder.status || "pending").slice(1)}
                  </span>
                </div>
              </div>

              <div>
                <p className="text-sm font-medium text-gray-500">Date</p>
                <p className="text-sm text-gray-900">
                  {selectedOrder.created_at ? moment(selectedOrder.created_at).format("MMMM D, YYYY, h:mm A") : "—"}
                </p>
              </div>

              {/* Ordered Items */}
              {selectedOrder.order_items && selectedOrder.order_items.length > 0 && (
                <div className="border-t border-gray-200 pt-4">
                  <p className="text-sm font-medium text-gray-500 mb-3">Ordered Items</p>
                  <div className="space-y-3">
                    {selectedOrder.order_items.map((item) => (
                      <div key={item.id} className="p-4 bg-gray-50 rounded-lg border border-gray-200">
                        <div className="flex justify-between items-start">
                          <div className="flex-1">
                            <p className="text-sm font-medium text-gray-900">{item.name || "Unknown Item"}</p>
                            <p className="text-xs text-gray-600 mt-1">Quantity: {item.quantity || 1}</p>
                          </div>
                          <div className="text-sm font-medium text-gray-900">
                            ${((item.unit_price || 0) * (item.quantity || 1)).toFixed(2)}
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              <div className="border-t border-gray-200 pt-4">
                <p className="text-sm font-medium text-gray-500 mb-3">Price Breakdown</p>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-gray-600">Subtotal:</span>
                    <span className="text-gray-900">${(selectedOrder.subtotal ?? 0).toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Tax:</span>
                    <span className="text-gray-900">${(selectedOrder.tax ?? 0).toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Delivery Fee:</span>
                    <span className="text-gray-900">${(selectedOrder.delivery_fee ?? 0).toFixed(2)}</span>
                  </div>
                </div>
              </div>
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

    </div>
  );
}
