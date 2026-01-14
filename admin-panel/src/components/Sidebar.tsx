import { Link, useLocation } from "react-router-dom";
import { LayoutDashboard, ShoppingBag, Utensils, Users, BarChart3, Settings, MessageCircle, Calendar, Car, Star } from "lucide-react";
import logo from "../assets/images/logo.png";

const navItems = [
  { name: "Dashboard", path: "/", icon: LayoutDashboard },
  { name: "Orders", path: "/orders", icon: ShoppingBag },
  { name: "Scheduled Orders", path: "/scheduled-orders", icon: Calendar },
  { name: "Meals", path: "/meals", icon: Utensils },
  { name: "Customers", path: "/users", icon: Users },
  { name: "Drivers", path: "/drivers", icon: Car },
  { name: "Reviews", path: "/reviews", icon: Star },
  { name: "Support", path: "/support", icon: MessageCircle },
  { name: "Analytics", path: "/analytics", icon: BarChart3 },
  { name: "Settings", path: "/settings", icon: Settings },
];

export default function Sidebar({ className = "" }) {
  const location = useLocation();

  return (
    <aside className={`w-64 bg-white border-r border-gray-200 h-screen fixed top-0 left-0 z-40 shadow-sm transition-all duration-300 ${className}`}>
      <div className="p-6 border-b border-gray-200 flex items-center gap-3">
        <img 
          src={logo} 
          alt="Logo" 
          className="h-12 w-12 rounded-xl object-cover shadow-md"
        />
        <div className="text-xl font-bold text-gray-900 tracking-tight">
          Taste of African Cuisine
        </div>
      </div>
      <nav className="flex flex-col p-4 gap-1">
        {navItems.map((item) => {
          const isActive = location.pathname === item.path;
          const Icon = item.icon;
          return (
            <Link
              key={item.name}
              to={item.path}
              className={`flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium transition-all duration-200 ${
                isActive
                  ? "bg-amber-100 text-amber-900 border-r-2 border-amber-500"
                  : "text-gray-700 hover:bg-gray-100 hover:text-gray-900"
              }`}
              aria-current={isActive ? "page" : undefined}
            >
              <Icon className="w-5 h-5" />
              {item.name}
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}