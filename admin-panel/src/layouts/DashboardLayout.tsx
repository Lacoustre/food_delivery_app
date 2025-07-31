import { useEffect, useRef, useState } from "react";
import { useNavigate } from "react-router-dom";
import { signOut } from "firebase/auth";
import { LogOut, User } from "lucide-react";
import Sidebar from "../components/Sidebar";
import NotificationCenter from "../components/NotificationCenter";
import { auth } from "../firebase";

import type { ReactNode } from "react";

interface DashboardLayoutProps {
  children: ReactNode;
}

export default function DashboardLayout({ children }: DashboardLayoutProps) {
  const navigate = useNavigate();
  const [showModal, setShowModal] = useState(false);
  const [showDropdown, setShowDropdown] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Close dropdown when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (
        dropdownRef.current &&
        !dropdownRef.current.contains(event.target as Node)
      ) {
        setShowDropdown(false);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, []);

  const handleLogout = async () => {
    setIsLoading(true);
    setError(null);
    try {
      await signOut(auth);
      navigate("/login");
    } catch (err) {
      console.error("Logout failed", err);
      setError("Failed to log out. Please try again.");
    } finally {
      setIsLoading(false);
      setShowModal(false);
    }
  };

  return (
    <div className="flex min-h-screen bg-gray-50">
      <Sidebar />

      <div className="flex-1 pl-64">
        {/* Topbar */}
        <header className="h-16 bg-white border-b border-gray-200 flex items-center justify-between px-6 fixed top-0 left-64 right-0 z-30 shadow-sm">
          <h1 className="text-xl md:text-2xl font-bold text-gray-900 tracking-tight">
            Dashboard
          </h1>

          <div className="flex items-center gap-4">
            {/* Notification Center */}
            <NotificationCenter />
            
            {/* User Dropdown */}
            <div className="relative" ref={dropdownRef}>
            <button
              onClick={() => setShowDropdown((prev) => !prev)}
              className="flex items-center gap-2 px-3 py-2 text-gray-700 font-medium text-sm hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-all duration-200"
            >
              <User className="w-5 h-5" />
              <span className="hidden md:block">Welcome, Admin</span>
            </button>
            {showDropdown && (
              <div className="absolute right-0 mt-2 w-48 bg-white rounded-xl shadow-xl z-50 border border-gray-200">
                <button
                  onClick={() => {
                    setShowModal(true);
                    setShowDropdown(false);
                  }}
                  className="block w-full text-left px-4 py-3 text-sm text-gray-700 font-medium hover:bg-gray-50 hover:text-gray-900 transition-all duration-200 rounded-xl"
                >
                  <LogOut className="w-4 h-4 inline mr-2" />
                  Logout
                </button>
              </div>
            )}
            </div>
          </div>
        </header>

        {/* Main Content */}
        <main className="p-6 mt-16 bg-white min-h-[calc(100vh-4rem)]">
          {children}
        </main>

        {/* Logout Confirmation Modal */}
        {showModal && (
          <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 backdrop-blur-sm">
            <div className="bg-white p-8 rounded-2xl shadow-2xl w-full max-w-md border border-gray-200">
              <h2 className="text-xl font-bold text-gray-900 mb-4">
                Confirm Logout
              </h2>
              <p className="text-gray-600 mb-6">
                Are you sure you want to log out of the admin panel?
              </p>
              {error && (
                <p className="text-sm text-red-600 bg-red-50 p-3 rounded-lg mb-4 border border-red-200">{error}</p>
              )}
              <div className="flex justify-end gap-3">
                <button
                  onClick={() => setShowModal(false)}
                  className="px-4 py-2 rounded-lg border border-gray-300 text-gray-700 hover:bg-gray-50 font-medium transition-all duration-200"
                >
                  Cancel
                </button>
                <button
                  onClick={handleLogout}
                  disabled={isLoading}
                  className={`px-4 py-2 rounded-lg bg-red-600 text-white hover:bg-red-700 focus:ring-2 focus:ring-red-500 focus:ring-offset-2 font-medium transition-all duration-200 ${
                    isLoading ? "opacity-50 cursor-not-allowed" : ""
                  }`}
                >
                  {isLoading ? "Logging out..." : "Logout"}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}