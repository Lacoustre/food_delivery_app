import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import moment from 'moment';
import Loader from '../components/Loader';

// Scheduled orders are just orders rows with scheduled_for set — there is
// no separate collection anymore (the old Firestore scheduled_orders one
// stopped being written when order persistence moved to Supabase).
interface ScheduledOrder {
  id: string;
  order_number: string | null;
  status: string;
  order_type: 'delivery' | 'pickup' | null;
  payment_method: string | null;
  scheduled_for: string;
  total: number;
  order_items: { name: string | null; quantity: number }[];
  profiles: { name: string | null; email: string | null } | { name: string | null; email: string | null }[] | null;
}

const STATUS_OPTIONS = [
  'pending', 'confirmed', 'preparing', 'ready for pickup', 'on the way',
  'delivered', 'picked up', 'completed', 'cancelled',
];

export default function ScheduledOrders() {
  const [orders, setOrders] = useState<ScheduledOrder[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchOrders = useCallback(async () => {
    const { data, error } = await supabase
      .from('orders')
      .select('id, order_number, status, order_type, payment_method, scheduled_for, total, order_items(name, quantity), profiles!user_id(name, email)')
      .not('scheduled_for', 'is', null)
      .order('scheduled_for', { ascending: true });
    if (!error) setOrders((data ?? []) as ScheduledOrder[]);
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchOrders();
    const channel = supabase
      .channel('scheduled-orders-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'orders' }, fetchOrders)
      .subscribe();
    return () => {
      supabase.removeChannel(channel);
    };
  }, [fetchOrders]);

  const updateOrderStatus = async (orderId: string, newStatus: string) => {
    try {
      const { error } = await supabase.from('orders').update({ status: newStatus }).eq('id', orderId);
      if (error) throw error;
    } catch (error) {
      console.error('Error updating order status:', error);
    }
  };

  const getCustomerName = (order: ScheduledOrder) => {
    const profile = Array.isArray(order.profiles) ? order.profiles[0] : order.profiles;
    return profile?.name || profile?.email?.split('@')[0] || 'Unknown Customer';
  };

  const showOrderDetails = (order: ScheduledOrder) => {
    alert(`Order Details:\n\nOrder #: ${order.order_number || 'N/A'}\nCustomer: ${getCustomerName(order)}\nItems: ${order.order_items?.length || 0}\nTotal: $${Number(order.total ?? 0).toFixed(2)}\nPayment: ${order.payment_method || 'N/A'}\nScheduled: ${moment(order.scheduled_for).format('MMM D, YYYY h:mm A')}`);
  };

  if (loading) {
    return (
      <div className="flex justify-center items-center h-64">
        <Loader />
      </div>
    );
  }

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Scheduled Orders</h1>
        <p className="text-gray-600">Manage customer scheduled orders for future delivery/pickup.</p>
      </div>

      {orders.length === 0 ? (
        <div className="bg-white border border-gray-200 rounded-xl p-12 text-center">
          <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <span className="text-2xl">📅</span>
          </div>
          <p className="text-gray-600 text-lg font-medium mb-2">No scheduled orders</p>
          <p className="text-gray-500">Scheduled orders will appear here.</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-200">
            <h2 className="text-lg font-semibold text-gray-900">All Scheduled Orders ({orders.length})</h2>
          </div>
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-blue-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-blue-700 uppercase tracking-wider">Order #</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-blue-700 uppercase tracking-wider">Customer</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-blue-700 uppercase tracking-wider">Scheduled Time</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-blue-700 uppercase tracking-wider">Total</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-blue-700 uppercase tracking-wider">Type</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-blue-700 uppercase tracking-wider">Payment</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-blue-700 uppercase tracking-wider">Status</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-blue-700 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {orders.map((order) => (
                  <tr key={order.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-mono text-gray-900">
                      #{order.order_number || order.id.slice(0, 8)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {getCustomerName(order)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {moment(order.scheduled_for).format('MMM D, YYYY h:mm A')}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      ${Number(order.total ?? 0).toFixed(2)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {order.order_type === 'pickup' ? '🏪 Pickup' : '🚚 Delivery'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                        {order.payment_method === 'cash' ? '💵 Cash' : '💳 Card'}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <select
                        value={order.status}
                        onChange={(e) => updateOrderStatus(order.id, e.target.value)}
                        className="text-sm px-3 py-1 border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-orange-500"
                      >
                        {STATUS_OPTIONS.map((status) => (
                          <option key={status} value={status}>
                            {status.charAt(0).toUpperCase() + status.slice(1)}
                          </option>
                        ))}
                      </select>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-blue-600">
                      <button
                        className="hover:text-blue-800 mr-2"
                        onClick={() => showOrderDetails(order)}
                      >
                        View Details
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
