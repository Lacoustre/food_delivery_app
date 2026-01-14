import { useState, useEffect } from 'react';
import { collection, query, orderBy, onSnapshot, updateDoc, doc } from 'firebase/firestore';
import { db } from '../firebase';
import moment from 'moment';
import Loader from '../components/Loader';

interface ScheduledOrder {
  id: string;
  orderNumber: string;
  userId: string;
  customerName?: string;
  name?: string;
  customer?: string;
  items: any[];
  pricing: {
    total: number;
    subtotal: number;
    tax: number;
    deliveryFee: number;
    tip: number;
  };
  delivery: {
    option: string;
    fee: number;
    address?: any;
  };
  payment: {
    method: string;
    status: string;
    processedAt: string;
  };
  scheduledTime: { seconds: number };
  status: string;
  createdAt: string;
  updatedAt: string;
}

export default function ScheduledOrders() {
  const [orders, setOrders] = useState<ScheduledOrder[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const ordersQuery = query(
      collection(db, 'scheduled_orders'),
      orderBy('scheduledTime', 'asc')
    );

    const unsubscribe = onSnapshot(ordersQuery, (snapshot) => {
      const orderData = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      })) as ScheduledOrder[];
      setOrders(orderData);
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const updateOrderStatus = async (orderId: string, newStatus: string) => {
    try {
      await updateDoc(doc(db, 'scheduled_orders', orderId), {
        status: newStatus
      });
    } catch (error) {
      console.error('Error updating order status:', error);
    }
  };

  const getCustomerName = (order: ScheduledOrder) => {
    return order.customerName || order.name || order.customer || 'Unknown Customer';
  };

  const showOrderDetails = (order: ScheduledOrder) => {
    alert(`Order Details:\n\nOrder #: ${order.orderNumber || 'N/A'}\nCustomer: ${getCustomerName(order)}\nItems: ${order.items?.length || 0}\nTotal: $${order.pricing?.total?.toFixed(2) || '0.00'}\nPayment: ${order.payment?.method || 'N/A'} (${order.payment?.status || 'N/A'})\nScheduled: ${moment(order.scheduledTime?.seconds * 1000).format('MMM D, YYYY h:mm A')}`);
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
                      #{order.orderNumber}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {getCustomerName(order)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {moment(order.scheduledTime.seconds * 1000).format('MMM D, YYYY h:mm A')}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                      ${order.pricing?.total?.toFixed(2) || '0.00'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {order.delivery?.option === 'Pickup' ? '🏪 Pickup' : '🚚 Delivery'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        order.payment?.status === 'completed' 
                          ? 'bg-green-100 text-green-800' 
                          : 'bg-red-100 text-red-800'
                      }`}>
                        {order.payment?.status === 'completed' ? '✅ Paid' : '❌ Unpaid'}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <select
                        value={order.status}
                        onChange={(e) => updateOrderStatus(order.id, e.target.value)}
                        className="text-sm px-3 py-1 border border-gray-300 rounded focus:outline-none focus:ring-1 focus:ring-orange-500"
                      >
                        <option value="scheduled">Scheduled</option>
                        <option value="confirmed">Confirmed</option>
                        <option value="preparing">Preparing</option>
                        <option value="ready">Ready</option>
                        <option value="completed">Completed</option>
                        <option value="cancelled">Cancelled</option>
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