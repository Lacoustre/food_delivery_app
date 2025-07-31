import { BrowserRouter as Router, Routes, Route } from "react-router-dom";
import DashboardLayout from "./layouts/DashboardLayout";
import Dashboard from "./pages/Dashboard";
import Orders from "./pages/Orders";
import Meals from "./pages/Meals";
import Users from "./pages/Users";
import Notifications from "./pages/Notifications";
import LoginPage from "./pages/LoginPage";
import ProtectedRoute from "./components/ProtectedRoute";
import { ToastContainer } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route
          path="/"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <Dashboard />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/orders"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <Orders />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/meals"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <Meals />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/users"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <Users />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />
        <Route
          path="/notifications"
          element={
            <ProtectedRoute>
              <DashboardLayout>
                <Notifications />
              </DashboardLayout>
            </ProtectedRoute>
          }
        />
      </Routes>

      <ToastContainer
        position="top-center"
        autoClose={3000}
        hideProgressBar={false}
        pauseOnHover
        theme="light"
      />
    </Router>
  );
}

export default App;