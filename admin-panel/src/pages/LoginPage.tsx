import { useState } from "react";
import {
  signInWithEmailAndPassword,
  sendPasswordResetEmail,
} from "firebase/auth";
import { useNavigate } from "react-router-dom";
import { auth } from "../firebase";
import Loader from "../components/Loader";
import { toast } from "react-toastify";
import { Eye, EyeOff } from "lucide-react";
import logo from "../assets/images/logo.png";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showReset, setShowReset] = useState(false);
  const navigate = useNavigate();

  const handleLogin = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setIsLoading(true);

    try {
      await signInWithEmailAndPassword(auth, email, password);
      toast.success("Login successful!", {
        position: "top-right",
        autoClose: 2000,
      });
      setTimeout(() => navigate("/"), 1000);
    } catch (error) {
      const messageMap = {
        "auth/invalid-email": "Invalid email address.",
        "auth/user-disabled": "Account disabled.",
        "auth/user-not-found": "User not found.",
        "auth/wrong-password": "Incorrect password.",
        "auth/invalid-credential": "Incorrect email or password.",
      };
      let msg = "Something went wrong.";
      if (
        error &&
        typeof error === "object" &&
        "code" in error &&
        typeof error.code === "string"
      ) {
        const code = error.code;
        msg = messageMap[code as keyof typeof messageMap] || "Login failed.";
      }
      toast.error(msg, {
        position: "top-right",
        autoClose: 3000,
      });
    } finally {
      setIsLoading(false);
    }
  };

  const handleResetPassword = async () => {
    if (!email) {
      toast.error("Please enter your email first.", {
        position: "top-right",
        autoClose: 3000,
      });
      return;
    }
    try {
      await sendPasswordResetEmail(auth, email);
      toast.success("Password reset link sent!", {
        position: "top-right",
        autoClose: 3000,
      });
      setShowReset(false);
    } catch {
      toast.error("Reset failed. Please try again.", {
        position: "top-right",
        autoClose: 3000,
      });
    }
  };

  return (
    <div className="h-screen w-screen flex overflow-hidden">
      {/* Left Side - Branding */}
      <div className="hidden lg:flex lg:w-3/5 bg-gradient-to-br from-amber-500 via-orange-500 to-red-500 relative overflow-hidden">
        {/* Animated background elements */}
        <div className="absolute inset-0">
          <div className="absolute top-20 left-20 w-64 h-64 bg-white/10 rounded-full blur-3xl animate-pulse"></div>
          <div className="absolute bottom-20 right-20 w-48 h-48 bg-white/5 rounded-full blur-2xl animate-pulse delay-1000"></div>
          <div className="absolute top-1/2 left-1/3 w-32 h-32 bg-white/5 rounded-full blur-xl animate-pulse delay-500"></div>
        </div>
        <div className="absolute inset-0 bg-gradient-to-t from-black/20 via-transparent to-black/10"></div>
        
        <div className="relative z-10 flex flex-col justify-center items-center text-center p-12 text-white ml-24">
          <div className="mb-10 relative">
            <div className="absolute -inset-4 bg-white/20 rounded-full blur-xl animate-pulse"></div>
            <img 
              src={logo} 
              alt="Taste of African Cuisine Logo" 
              className="relative w-36 h-36 mx-auto rounded-full shadow-2xl object-cover border-4 border-white/30 transform hover:scale-105 transition-transform duration-500"
            />
          </div>
          <h1 className="text-6xl font-black mb-6 leading-tight drop-shadow-lg">
            Taste of
            <br />
            <span className="text-yellow-200">African</span>
            <br />
            Cuisine
          </h1>
          <p className="text-xl opacity-90 max-w-lg leading-relaxed mb-8">
            Experience authentic African flavors with our premium dining experience
          </p>
          <div className="bg-white/10 backdrop-blur-sm rounded-full px-6 py-3 border border-white/20">
            <span className="text-lg font-semibold">Admin Dashboard</span>
          </div>
        </div>
      </div>

      {/* Right Side - Login Form */}
      <div className="w-full lg:w-2/5 bg-gradient-to-br from-gray-50 to-white flex items-center justify-center p-8 relative">
        {isLoading && (
          <div className="absolute inset-0 z-50 flex items-center justify-center bg-white/95 backdrop-blur-md">
            <div className="text-center bg-white rounded-2xl p-8 shadow-xl border border-gray-200">
              <Loader />
              <p className="mt-4 text-gray-700 font-semibold">Signing you in...</p>
            </div>
          </div>
        )}
        
        <div className="w-full max-w-md">
          {/* Mobile Logo */}
          <div className="lg:hidden text-center mb-10">
            <div className="relative inline-block mb-6">
              <div className="absolute -inset-2 bg-gradient-to-r from-amber-400 to-orange-400 rounded-2xl blur opacity-75"></div>
              <img 
                src={logo} 
                alt="Taste of African Cuisine Logo" 
                className="relative w-24 h-24 mx-auto rounded-2xl shadow-xl object-cover"
              />
            </div>
            <h1 className="text-3xl font-black text-gray-900 mb-2">Admin Portal</h1>
            <p className="text-gray-600">Taste of African Cuisine</p>
          </div>

          {/* Desktop Header */}
          <div className="hidden lg:block mb-10">
            <h2 className="text-4xl font-black text-gray-900 mb-3">Welcome Back</h2>
            <p className="text-gray-600 text-lg">Sign in to manage your restaurant</p>
          </div>

          <div className="bg-white rounded-2xl shadow-xl p-8 border border-gray-100">
            <form onSubmit={handleLogin} className="space-y-6">
              <div>
                <label htmlFor="email" className="block text-sm font-semibold text-gray-700 mb-3">
                  Email Address
                </label>
                <input
                  id="email"
                  type="email"
                  placeholder="admin@restaurant.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  className="w-full px-4 py-4 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-amber-500 focus:border-amber-500 transition-all duration-300 text-gray-900 placeholder-gray-400 hover:border-gray-300 shadow-sm"
                />
              </div>

              <div className="relative">
                <label htmlFor="password" className="block text-sm font-semibold text-gray-700 mb-3">
                  Password
                </label>
                <input
                  id="password"
                  type={showPassword ? "text" : "password"}
                  placeholder="Enter your password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  className="w-full px-4 py-4 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-amber-500 focus:border-amber-500 transition-all duration-300 text-gray-900 placeholder-gray-400 hover:border-gray-300 pr-12 shadow-sm"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-4 top-11 text-gray-400 hover:text-amber-600 transition-colors duration-200 p-1 rounded-lg hover:bg-amber-50"
                >
                  {showPassword ? <EyeOff size={22} /> : <Eye size={22} />}
                </button>
              </div>

              <button
                type="submit"
                disabled={isLoading}
                className="w-full py-4 bg-gradient-to-r from-amber-600 to-orange-600 text-white rounded-xl font-bold text-lg hover:from-amber-700 hover:to-orange-700 focus:ring-4 focus:ring-amber-500/50 transition-all duration-300 disabled:opacity-50 shadow-lg hover:shadow-xl transform hover:-translate-y-0.5 active:translate-y-0"
              >
                {isLoading ? "Signing in..." : "Sign In"}
              </button>
            </form>

            <div className="mt-8 text-center">
              <button
                onClick={() => setShowReset(!showReset)}
                className="text-amber-600 hover:text-amber-700 font-semibold transition-colors duration-200 hover:underline decoration-2 underline-offset-4"
              >
                {showReset ? "← Back to login" : "Forgot your password?"}
              </button>
            </div>

            {showReset && (
              <div className="mt-6 p-6 bg-gradient-to-br from-amber-50 to-orange-50 rounded-xl border border-amber-200 shadow-sm">
                <h3 className="font-bold text-gray-900 mb-3 text-lg">Reset Password</h3>
                <p className="text-sm text-gray-600 mb-4 leading-relaxed">
                  Enter your email above and we'll send you a secure reset link.
                </p>
                <button
                  onClick={handleResetPassword}
                  className="w-full py-3 bg-gradient-to-r from-gray-700 to-gray-800 text-white rounded-lg hover:from-gray-800 hover:to-gray-900 transition-all duration-200 font-semibold shadow-md hover:shadow-lg transform hover:-translate-y-0.5"
                >
                  Send Reset Link
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
