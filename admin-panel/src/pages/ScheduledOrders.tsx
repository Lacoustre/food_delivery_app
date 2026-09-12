import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../lib/supabase';
import moment from 'moment';
import { toast } from 'react-toastify';
import Loader from '../components/Loader';
import { netPaid } from '../lib/money';

// Scheduled orders are just orders rows with scheduled_for set — there is
// no separate collection anymore (the old Firestore scheduled_orders one
// stopped being written when order persistence moved to Supabase).
interface Profile {
  name: string | null;
  email: string | null;
  phone: string | null;
}

interface ScheduledOrder {
  id: string;
  order_number: string | null;
  status: string;
  order_type: 'delivery' | 'pickup' | null;
  payment_method: string | null;
  scheduled_for: string;
  created_at: string | null;
  delivery_address: string | null;
  subtotal: number | null;
  tax: number | null;
  delivery_fee: number | null;
  tip: number | null;
  total: number;
  refund_amount: number | null;
  order_items: { name: string | null; quantity: number; unit_price: number | null }[];
  profiles: Profile | Profile[] | null;
}

const STATUS_OPTIONS = [
  'pending', 'confirmed', 'preparing', 'ready for pickup', 'on the way',
  'delivered', 'picked up', 'completed', 'cancelled',
];

export default function ScheduledOrders() {
  const [orders, setOrders] = useState<ScheduledOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const fetchOrders = useCallback(async () => {
    const { data, error } = await supabase
      .from('orders')
      .select(
        'id, order_number, status, order_type, payment_method, scheduled_for, created_at, ' +
        'delivery_address, subtotal, tax, delivery_fee, tip, total, refund_amount, ' +
        'order_items(name, quantity, unit_price), profiles!user_id(name, email, phone)'
      )
      .not('scheduled_for', 'is', null)
      .order('scheduled_for', { ascending: true });
    // Cast through unknown: the select is built by concatenation, so
    // supabase-js cannot infer the row shape from the string literal.
    if (!error) setOrders((data ?? []) as unknown as ScheduledOrder[]);
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
      toast.success(`Marked ${newStatus}.`, { position: 'top-right', autoClose: 2000 });
    } catch (error) {
      // This silently failed before, so a dropdown could snap back with no
      // explanation and staff would assume the change had saved.
      console.error('Error updating order status:', error);
      toast.error('Could not update the status. Please try again.', {
        position: 'top-right',
        autoClose: 4000,
      });
    }
  };

  const getCustomerName = (order: ScheduledOrder) => {
    const profile = Array.isArray(order.profiles) ? order.profiles[0] : order.profiles;
    return profile?.name || profile?.email?.split('@')[0] || 'Unknown Customer';
  };


  const getProfile = (order: ScheduledOrder): Profile | null =>
    Array.isArray(order.profiles) ? order.profiles[0] ?? null : order.profiles;

  const selected = orders.find((o) => o.id === selectedId) ?? null;

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
                      ${netPaid(order).toFixed(2)}
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
                        onClick={() => setSelectedId(order.id)}
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

      {/* Details. Replaces a window.alert that reported a count of items
          without naming any of them — the one thing the kitchen needs. */}
      {selected && (
        <div
          className="fixed inset-0 bg-black/50 z-50 flex justify-center items-center backdrop-blur-sm p-4"
          onClick={() => setSelectedId(null)}
        >
          <div
            className="bg-white rounded-2xl shadow-2xl w-full max-w-lg border border-gray-200 max-h-[90vh] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between p-6 pb-4 sticky top-0 bg-white border-b border-gray-100">
              <div>
                <h2 className="text-xl font-bold text-gray-900">
                  Order #{selected.order_number || selected.id.slice(0, 8)}
                </h2>
                <p className="text-sm text-amber-700 font-medium mt-0.5">
                  {selected.order_type === 'pickup' ? 'Pickup' : 'Delivery'} &middot;{' '}
                  {moment(selected.scheduled_for).format('ddd D MMM, h:mm A')}
                </p>
              </div>
              <button
                onClick={() => setSelectedId(null)}
                className="text-gray-400 hover:text-gray-600 transition-colors"
              >
                <span className="sr-only">Close</span>
                <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <div className="p-6 pt-4 space-y-5">
              <div>
                <p className="text-sm font-medium text-gray-500 mb-1">Customer</p>
                <p className="text-sm text-gray-900">{getCustomerName(selected)}</p>
                {/* Tap-to-call: a scheduled order is the one most likely to
                    need a phone call, and staff are often on a phone. */}
                {getProfile(selected)?.phone && (
                  <a
                    href={`tel:${getProfile(selected)?.phone}`}
                    className="text-sm text-amber-700 hover:underline"
                  >
                    {getProfile(selected)?.phone}
                  </a>
                )}
                {getProfile(selected)?.email && (
                  <p className="text-sm text-gray-500 break-all">{getProfile(selected)?.email}</p>
                )}
              </div>

              {selected.order_type === 'delivery' && selected.delivery_address && (
                <div>
                  <p className="text-sm font-medium text-gray-500 mb-1">Deliver to</p>
                  <p className="text-sm text-gray-900">{selected.delivery_address}</p>
                </div>
              )}

              <div className="border-t border-gray-200 pt-4">
                <p className="text-sm font-medium text-gray-500 mb-3">
                  Items ({selected.order_items?.length ?? 0})
                </p>
                <div className="space-y-2">
                  {(selected.order_items ?? []).map((item, i) => (
                    <div
                      key={i}
                      className="flex justify-between items-start gap-3 p-3 bg-gray-50 rounded-lg border border-gray-200"
                    >
                      <div className="flex-1">
                        <p className="text-sm font-medium text-gray-900">
                          {item.quantity > 1 && (
                            <span className="text-amber-700 font-bold">{item.quantity} &times; </span>
                          )}
                          {item.name || 'Unknown item'}
                        </p>
                      </div>
                      <p className="text-sm text-gray-900 whitespace-nowrap">
                        ${((item.unit_price ?? 0) * (item.quantity || 1)).toFixed(2)}
                      </p>
                    </div>
                  ))}
                  {(selected.order_items?.length ?? 0) === 0 && (
                    <p className="text-sm text-red-600">
                      No items recorded on this order.
                    </p>
                  )}
                </div>
              </div>

              <div className="border-t border-gray-200 pt-4 space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="text-gray-600">Subtotal</span>
                  <span className="text-gray-900">${Number(selected.subtotal ?? 0).toFixed(2)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-gray-600">Tax</span>
                  <span className="text-gray-900">${Number(selected.tax ?? 0).toFixed(2)}</span>
                </div>
                {Number(selected.delivery_fee ?? 0) > 0 && (
                  <div className="flex justify-between">
                    <span className="text-gray-600">Delivery</span>
                    <span className="text-gray-900">${Number(selected.delivery_fee).toFixed(2)}</span>
                  </div>
                )}
                {Number(selected.tip ?? 0) > 0 && (
                  <div className="flex justify-between">
                    <span className="text-gray-600">Tip</span>
                    <span className="text-gray-900">${Number(selected.tip).toFixed(2)}</span>
                  </div>
                )}
                <div className="flex justify-between pt-2 border-t border-gray-200">
                  <span className="font-semibold text-gray-900">Total</span>
                  <span className="font-bold text-gray-900">${netPaid(selected).toFixed(2)}</span>
                </div>
                <div className="flex justify-between pt-1">
                  <span className="text-gray-600">Payment</span>
                  <span className={selected.payment_method === 'cash' ? 'text-amber-700 font-medium' : 'text-gray-900'}>
                    {selected.payment_method === 'cash' ? 'Cash on collection' : 'Paid by card'}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
