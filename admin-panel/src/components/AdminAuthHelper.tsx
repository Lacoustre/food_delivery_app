import { useAuthState } from "react-firebase-hooks/auth";
import { auth } from "../firebase";
import { AlertTriangle, LogOut } from "lucide-react";
import { signOut } from "firebase/auth";

export default function AdminAuthHelper() {
  const [user] = useAuthState(auth);
  
  const isAdmin = user?.email === 'tasteofafricancuisine01@gmail.com';
  
  if (!user || isAdmin) {
    return null;
  }
  
  const handleLogout = async () => {
    try {
      await signOut(auth);
    } catch (error) {
      console.error('Logout error:', error);
    }
  };
  
  return (
    <div className="fixed top-4 right-4 z-50 bg-red-50 border border-red-200 rounded-lg p-4 shadow-lg max-w-sm">
      <div className="flex items-start gap-3">
        <AlertTriangle className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
        <div className="flex-1">
          <h3 className="text-sm font-semibold text-red-800 mb-1">
            Admin Access Required
          </h3>
          <p className="text-xs text-red-700 mb-3">
            You're logged in as <strong>{user.email}</strong>, but admin access requires the restaurant admin email.
          </p>
          <button
            onClick={handleLogout}
            className="flex items-center gap-2 text-xs bg-red-600 text-white px-3 py-1.5 rounded hover:bg-red-700 transition-colors"
          >
            <LogOut className="w-3 h-3" />
            Switch Account
          </button>
        </div>
      </div>
    </div>
  );
}