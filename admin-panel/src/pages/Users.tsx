import { useCollection } from "react-firebase-hooks/firestore";
import { collection, query } from "firebase/firestore";
import { db } from "../firebase";
import { Users as UsersIcon } from "lucide-react";

// Define the customer type
interface Customer {
  id: string;
  name: string;
  email: string;
  role?: string;
}

export default function Users() {
  const customersQuery = query(collection(db, "users"));
  const [snapshot, loading, error] = useCollection(customersQuery);

  
  const customers: Customer[] = snapshot?.docs.map((doc) => ({
    id: doc.id,
    ...doc.data()
  })) as Customer[] || [];

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Customers</h1>
        <p className="text-gray-600">Manage your restaurant's customers and their information.</p>
      </div>

      {loading ? (
        <div className="flex justify-center items-center h-64">
          <div className="text-center">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
            <p className="text-gray-600">Loading customers...</p>
          </div>
        </div>
      ) : error ? (
        <div className="bg-red-50 border border-red-200 rounded-xl p-6 text-center">
          <p className="text-red-600 font-medium">Error loading customers: {String(error)}</p>
          {String(error).includes('permission') && (
            <div className="mt-4 p-4 bg-red-100 rounded-lg">
              <p className="text-sm text-red-800 font-medium">🔒 Firestore Security Rules Issue</p>
              <p className="text-sm text-red-700 mt-1">The admin account doesn't have permission to read the users collection.</p>
            </div>
          )}
        </div>
      ) : !customers || customers.length === 0 ? (
        <div className="bg-gray-50 border border-gray-200 rounded-xl p-12 text-center">
          <UsersIcon className="w-16 h-16 text-gray-400 mx-auto mb-4" />
          <p className="text-gray-600 text-lg font-medium mb-2">No customers found</p>
          <p className="text-gray-500">Customers will appear here once they start registering.</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-200">
            <h2 className="text-lg font-semibold text-gray-900">All Customers ({customers.length})</h2>
          </div>
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Name
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Email
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Role
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {customers.map((customer) => (
                  <tr key={customer.id} className="hover:bg-gray-50 transition-colors duration-150">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center">
                        <div className="h-10 w-10 bg-gradient-to-r from-blue-500 to-purple-500 rounded-full flex items-center justify-center">
                          <span className="text-white font-medium text-sm">
                            {customer.name?.charAt(0)?.toUpperCase() || 'C'}
                          </span>
                        </div>
                        <div className="ml-4">
                          <div className="text-sm font-medium text-gray-900">{customer.name || 'Unknown Customer'}</div>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-900">{customer.email}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-blue-100 text-blue-800 capitalize">
                        {customer.role || 'Customer'}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className="inline-flex px-2 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800">
                        Active
                      </span>
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