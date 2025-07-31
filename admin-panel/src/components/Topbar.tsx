import { LogOut } from "lucide-react";
import logo from "../assets/images/logo.png"; // Adjust path if needed

export default function Topbar() {
  return (
    <header className="h-16 bg-white dark:bg-gray-900 text-gray-800 dark:text-gray-100 flex items-center justify-between px-6 fixed top-0 left-64 right-0 z-30 shadow-lg border-b border-gray-200/80 dark:border-gray-700/80">
      {/* Logo and Title */}
      <div className="flex items-center gap-3">
        <img
          src={logo}
          alt="Admin Dashboard Logo"
          className="h-10 w-10 rounded-full object-cover border-2 border-amber-300 dark:border-amber-400 shadow-sm"
        />
        <h1 className="text-xl md:text-2xl font-semibold text-amber-600 dark:text-amber-400 tracking-tight">
          Admin Dashboard
        </h1>
      </div>

      {/* Right-side Controls */}
      <div className="flex items-center gap-4">
        <span className="hidden md:block font-medium text-gray-600 dark:text-gray-300 text-sm">
          Welcome, Admin
        </span>
        <button
          type="button"
          aria-label="Logout"
          className="flex items-center px-4 py-2 bg-amber-500 dark:bg-amber-600 text-white rounded-lg hover:bg-amber-600 dark:hover:bg-amber-700 focus:ring-2 focus:ring-amber-400 dark:focus:ring-amber-500 focus:ring-opacity-50 transition-all duration-300 text-sm font-medium shadow-sm"
        >
          <LogOut className="w-4 h-4 mr-2" />
          <span className="hidden sm:inline">Logout</span>
        </button>
      </div>
    </header>
  );
}