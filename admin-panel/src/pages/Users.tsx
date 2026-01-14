import { useState } from "react";
import { useCollection } from "react-firebase-hooks/firestore";
import { collection, query, orderBy } from "firebase/firestore";
import { db } from "../firebase";
import Loader from "../components/Loader";
import moment from "moment";

interface User {
  id: string;
  name?: string;
  displayName?: string;
  email?: string;
  phoneNumber?: string;
  phone?: string;
  createdAt?: { seconds: number };
  active?: boolean;
  role?: string;
}

interface Order {
  id: string;
  userId?: string;
  status: string;
  deliveryStatus?: string;
  createdAt?: { seconds: number };
  pricing?: { total?: number };
  total?: number;
}

export default function Users() {
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  
  const [usersSnapshot, usersLoading, usersError] = useCollection(
    query(collection(db, "users"), orderBy("createdAt", "desc"))
  );
  
  const [ordersSnapshot, ordersLoading] = useCollection(
    query(collection(db, "orders"), orderBy("createdAt", "desc"))
  );

  const users: User[] = usersSnapshot?.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  })) as User[] || [];
  
  const orders: Order[] = ordersSnapshot?.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  })) as Order[] || [];

  const getUserOrders = (userId: string) => {
    return orders.filter(order => order.userId === userId);
  };

  const getUserStats = (userId: string) => {
    const userOrders = getUserOrders(userId);
    const completedOrders = userOrders.filter(order => {
      const status = order.deliveryStatus || order.status;
      return status === 'delivered' || status === 'picked up' || status === 'completed';
    });
    const totalSpent = completedOrders.reduce((sum, order) => 
      sum + (order.pricing?.total || order.total || 0), 0
    );
    const avgOrderValue = completedOrders.length > 0 ? totalSpent / completedOrders.length : 0;
    
    return {
      totalOrders: userOrders.length,
      completedOrders: completedOrders.length,
      totalSpent,
      avgOrderValue,
      lastOrderDate: userOrders[0]?.createdAt?.seconds ? 
        moment(userOrders[0].createdAt.seconds * 1000).format("MMM D, YYYY") : null
    };
  };

  if (usersLoading || ordersLoading) {
    return (
      <div className="flex justify-center items-center h-[70vh]">
        <Loader />
      </div>
    );
  }

  if (usersError) {
    // Silently handle permission errors
    if (usersError.toString().includes('Missing or insufficient permissions')) {
      // Continue with empty state
    } else {
      return (
        <div className="text-center text-red-900 font-semibold bg-red-100 p-4 rounded-xl max-w-6xl mx-auto">
          Failed to load users: {usersError.message}
        </div>
      );
    }
  }

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Customers</h1>
        <p className="text-gray-600">View customer profiles and order history.</p>
      </div>

      {users.length === 0 ? (
        <div className="bg-white border border-gray-200 rounded-xl p-12 text-center">
          <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <span className="text-2xl">👥</span>
          </div>
          <p className="text-gray-600 text-lg font-medium mb-2">No customers found</p>
          <p className="text-gray-500">Customers will appear here once they register.</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-200">
            <h2 className="text-lg font-semibold text-gray-900">All Customers ({users.length})</h2>
          </div>
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-blue-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-blue-700 uppercase tracking-wider">Customer</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-blue-700 uppercase tracking-wider">Contact</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-blue-700 uppercase tracking-wider">Orders</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-blue-700 uppercase tracking-wider">Total Spent</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-blue-700 uppercase tracking-wider">Last Order</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-blue-700 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {users.map((user) => {
                  const stats = getUserStats(user.id);
                  return (
                    <tr key={user.id} className="hover:bg-gray-50 transition-colors duration-150">
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        <div className="flex items-center">
                          <div className="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center mr-3">
                            <span className="text-blue-600 font-medium">
                              {(user.name || user.displayName || user.email || 'U').charAt(0).toUpperCase()}
                            </span>
                          </div>
                          <div>
                            <div className="font-medium">{user.name || user.displayName || (user.email ? user.email.split('@')[0] : 'No name')}</div>
                            <div className="text-gray-500 text-xs">ID: {user.id.substring(0, 8)}...</div>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        <div>
                          <div>{user.email || '—'}</div>
                          <div className="text-gray-500 text-xs">{user.phoneNumber || user.phone || '—'}</div>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        <div>
                          <div className="font-medium">{stats.totalOrders}</div>
                          <div className="text-gray-500 text-xs">{stats.completedOrders} completed</div>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        <div>
                          <div className="font-medium">${stats.totalSpent.toFixed(2)}</div>
                          <div className="text-gray-500 text-xs">Avg: ${stats.avgOrderValue.toFixed(2)}</div>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                        {stats.lastOrderDate || '—'}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                        <button
                          onClick={() => setSelectedUser(user)}
                          className="text-blue-600 hover:text-blue-800 transition-colors duration-150"
                        >
                          View Profile
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Customer Profile Modal */}
      {selectedUser && (
        <div className="fixed inset-0 bg-black/50 z-50 flex justify-center items-center backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-4xl max-h-[90vh] overflow-y-auto border border-gray-200 m-4">
            <div className="sticky top-0 bg-white border-b border-gray-200 px-8 py-6 rounded-t-2xl">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-4">
                  <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center">
                    <span className="text-blue-600 font-bold text-xl">
                      {(selectedUser.name || selectedUser.displayName || selectedUser.email || 'U').charAt(0).toUpperCase()}
                    </span>
                  </div>
                  <div>
                    <h2 className="text-2xl font-bold text-gray-900">
                      {selectedUser.name || selectedUser.displayName || (selectedUser.email ? selectedUser.email.split('@')[0] : 'Customer')}
                    </h2>
                    <p className="text-gray-600">Customer Profile</p>
                  </div>
                </div>
                <button
                  onClick={() => setSelectedUser(null)}
                  className="text-gray-400 hover:text-gray-600 transition-colors"
                >
                  <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
            </div>
            
            <div className="p-8">
              {/* Customer Info */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
                <div className="bg-gray-50 rounded-lg p-4">
                  <h3 className="font-semibold text-gray-900 mb-3">Contact Information</h3>
                  <div className="space-y-2 text-sm">
                    <div><span className="text-gray-600">Email:</span> {selectedUser.email || '—'}</div>
                    <div><span className="text-gray-600">Phone:</span> {selectedUser.phoneNumber || selectedUser.phone || '—'}</div>
                    <div><span className="text-gray-600">Customer ID:</span> {selectedUser.id}</div>
                    <div><span className="text-gray-600">Joined:</span> {selectedUser.createdAt?.seconds ? moment(selectedUser.createdAt.seconds * 1000).format("MMMM D, YYYY") : '—'}</div>
                  </div>
                </div>
                
                <div className="bg-gray-50 rounded-lg p-4">
                  <h3 className="font-semibold text-gray-900 mb-3">Order Statistics</h3>
                  {(() => {
                    const stats = getUserStats(selectedUser.id);
                    return (
                      <div className="space-y-2 text-sm">
                        <div><span className="text-gray-600">Total Orders:</span> {stats.totalOrders}</div>
                        <div><span className="text-gray-600">Completed Orders:</span> {stats.completedOrders}</div>
                        <div><span className="text-gray-600">Total Spent:</span> ${stats.totalSpent.toFixed(2)}</div>
                        <div><span className="text-gray-600">Average Order:</span> ${stats.avgOrderValue.toFixed(2)}</div>
                      </div>
                    );
                  })()}
                </div>
              </div>
              
              {/* Order History */}
              <div>
                <h3 className="font-semibold text-gray-900 mb-4">Order History</h3>
                {(() => {
                  const userOrders = getUserOrders(selectedUser.id);
                  return userOrders.length === 0 ? (
                    <div className="text-center py-8 text-gray-500">
                      <p>No orders found for this customer</p>
                    </div>
                  ) : (
                    <div className="space-y-3 max-h-96 overflow-y-auto">
                      {userOrders.map((order) => (
                        <div key={order.id} className="border border-gray-200 rounded-lg p-4">
                          <div className="flex justify-between items-start mb-2">
                            <div>
                              <p className="font-medium text-gray-900">Order #{order.id.substring(0, 8)}</p>
                              <p className="text-sm text-gray-600">
                                {order.createdAt?.seconds ? moment(order.createdAt.seconds * 1000).format("MMM D, YYYY h:mm A") : '—'}
                              </p>
                            </div>
                            <div className="text-right">
                              <p className="font-medium text-gray-900">${(order.pricing?.total || order.total || 0).toFixed(2)}</p>
                              <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                                (() => {
                                  const status = order.deliveryStatus || order.status;
                                  return status === 'delivered' || status === 'picked up' || status === 'completed' ? 'bg-green-100 text-green-800' :
                                         status === 'cancelled' ? 'bg-red-100 text-red-800' :
                                         'bg-yellow-100 text-yellow-800';
                                })()
                              }`}>
                                {(() => {
                                  const status = order.deliveryStatus || order.status;
                                  return status.charAt(0).toUpperCase() + status.slice(1);
                                })()}
                              </span>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  );
                })()}
              </div>
            </div>
            
            <div className="sticky bottom-0 bg-white border-t border-gray-200 px-8 py-4 rounded-b-2xl">
              <div className="flex justify-end">
                <button
                  onClick={() => setSelectedUser(null)}
                  className="px-4 py-2 bg-gray-100 text-gray-900 rounded-lg hover:bg-gray-200 font-medium transition-colors duration-200"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}