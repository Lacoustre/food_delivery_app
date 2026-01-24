import { useCollection, useDocumentData } from "react-firebase-hooks/firestore";
import {
  collection,
  query,
  orderBy,
  Timestamp,
  updateDoc,
  doc,
  addDoc,
  deleteDoc,
  setDoc,
  getDocs,
} from "firebase/firestore";
import { getStorage, ref, uploadBytes, getDownloadURL } from "firebase/storage";
import { db, storage } from "../firebase";
import moment from "moment";
import { useState, useEffect } from "react";
import jsPDF from "jspdf";
import autoTable from "jspdf-autotable";
import { toast } from "react-toastify";
import { Search, Plus, Filter, Edit, Trash2, X, Upload, Image as ImageIcon, CheckCircle, XCircle, Copy, MoreHorizontal, TrendingUp, DollarSign } from "lucide-react";

interface Meal {
  id: string;
  name: string;
  description: string;
  price: number;
  active: boolean;
  imageUrl?: string;
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
  available?: boolean;
  category?: string;
}



const CATEGORIES = [
  'Main Dishes',
  'Side Dishes', 
  'Pastries',
  'Drinks'
];

const getImageUrl = (imageUrl) => {
  if (!imageUrl) return null;
  if (imageUrl.startsWith('http')) return imageUrl;
  if (imageUrl.startsWith('assets/')) return `/${imageUrl}`;
  return imageUrl;
};

export default function Meals() {
  const [searchTerm, setSearchTerm] = useState("");
  const [statusFilter, setStatusFilter] = useState<"all" | "active" | "inactive">("all");
  const [availabilityFilter, setAvailabilityFilter] = useState<"all" | "available" | "unavailable">("all");
  const [categoryFilter, setCategoryFilter] = useState<string>("all");
  const [selectedMeals, setSelectedMeals] = useState<string[]>([]);
  const [showBulkActions, setShowBulkActions] = useState(false);
  const [mealAnalytics, setMealAnalytics] = useState<any[]>([]);
  const [analyticsLoading, setAnalyticsLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [editingMeal, setEditingMeal] = useState<Meal | null>(null);
  const [restaurantOpen, setRestaurantOpen] = useState(true);
  const [newMeal, setNewMeal] = useState({ name: "", description: "", price: "", category: "Main Dishes" });
  const [selectedImage, setSelectedImage] = useState<File | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);
  
  // Restaurant status query - using same approach as Dashboard
  const [restaurantDoc] = useDocumentData(doc(db, "settings", "restaurant"));
  
  // Update local state when Firestore data changes
  useEffect(() => {
    if (restaurantDoc) {
      setRestaurantOpen(restaurantDoc.isOpen ?? true);
    }
  }, [restaurantDoc]);

  // Load meal analytics
  useEffect(() => {
    loadMealAnalytics();
  }, []);

  const loadMealAnalytics = async () => {
    try {
      const ordersSnapshot = await getDocs(collection(db, "orders"));
      const mealStats = new Map();
      
      ordersSnapshot.docs.forEach(doc => {
        const order = doc.data();
        if (order.items && Array.isArray(order.items)) {
          order.items.forEach((item: any) => {
            const mealName = item.name;
            const quantity = item.quantity || 1;
            const price = item.price || 0;
            const revenue = quantity * price;
            
            if (mealStats.has(mealName)) {
              const existing = mealStats.get(mealName);
              mealStats.set(mealName, {
                ...existing,
                totalOrders: existing.totalOrders + quantity,
                totalRevenue: existing.totalRevenue + revenue
              });
            } else {
              mealStats.set(mealName, {
                name: mealName,
                totalOrders: quantity,
                totalRevenue: revenue
              });
            }
          });
        }
      });
      
      const analyticsArray = Array.from(mealStats.values())
        .sort((a, b) => b.totalOrders - a.totalOrders)
        .slice(0, 10);
      
      setMealAnalytics(analyticsArray);
    } catch (err) {
      console.error('Failed to load analytics:', err);
    } finally {
      setAnalyticsLoading(false);
    }
  };

  const mealsQuery = query(
    collection(db, "meals"),
    orderBy("createdAt", "desc")
  );

  const [snapshot, loading, error] = useCollection(mealsQuery);

  const meals: Meal[] =
    snapshot?.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    })) as Meal[] ?? [];

  // Auto-categorize existing meals on component mount
  useEffect(() => {
    const updateMealCategories = async () => {
      if (meals.length === 0) return;
      
      const updates = [];
      for (const meal of meals) {
        if (!meal.category) {
          const name = meal.name.toLowerCase();
          let category = 'Main Dishes'; // default
          
          if (name.includes('sprite') || name.includes('coke') || name.includes('fanta') || 
              name.includes('water') || name.includes('juice') || name.includes('malt') || 
              name.includes('sobolo') || name.includes('drink')) {
            category = 'Drinks';
          } else if (name.includes('shito') || name.includes('side')) {
            category = 'Side Dishes';
          } else if (name.includes('pastry') || name.includes('bread') || name.includes('cake')) {
            category = 'Pastries';
          } else if (name.includes('appetizer') || name.includes('starter')) {
            category = 'Appetizers';
          } else if (name.includes('dessert') || name.includes('sweet')) {
            category = 'Desserts';
          }
          
          if (category !== 'Main Dishes') {
            updates.push({
              id: meal.id,
              category
            });
          }
        }
      }
      
      // Update meals with categories
      if (updates.length > 0) {
        try {
          const promises = updates.map(update => 
            updateDoc(doc(db, "meals", update.id), { 
              category: update.category,
              updatedAt: Timestamp.now()
            })
          );
          await Promise.all(promises);
          console.log(`Updated ${updates.length} meals with categories`);
        } catch (err) {
          console.error('Failed to update meal categories:', err);
        }
      }
    };
    
    updateMealCategories();
  }, [meals.length]);

  const filteredMeals = meals.filter((meal) => {
    const matchesSearch = meal.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         meal.description.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesStatus = statusFilter === "all" || 
                         (statusFilter === "active" && meal.active) ||
                         (statusFilter === "inactive" && !meal.active);
    const matchesAvailability = availabilityFilter === "all" || 
                               (availabilityFilter === "available" && (meal.available !== false)) ||
                               (availabilityFilter === "unavailable" && meal.available === false);
    const matchesCategory = categoryFilter === "all" || meal.category === categoryFilter;
    return matchesSearch && matchesStatus && matchesAvailability && matchesCategory;
  });

  // Summary calculations
  const totalMeals = meals.length;
  const availableMeals = meals.filter(m => m.available !== false && m.active).length;
  const unavailableMeals = meals.filter(m => m.available === false || !m.active).length;
  const avgPrice = meals.length > 0 ? meals.reduce((sum, m) => sum + m.price, 0) / meals.length : 0;

  const exportMealsToPDF = () => {
    const exportable = filteredMeals.filter((meal) => meal.active);
    if (exportable.length === 0) {
      toast.warning("No meals found to export.");
      return;
    }

    const pdfDoc = new jsPDF();
    pdfDoc.setFontSize(24);
    pdfDoc.text("Taste of African Cuisine", 14, 20);
    pdfDoc.setFontSize(16);
    pdfDoc.text("Active Menu Items", 14, 45);

    autoTable(pdfDoc, {
      startY: 60,
      head: [["#", "Meal Name", "Description", "Price ($)"]],
      body: exportable.map((meal, idx) => [
        idx + 1,
        meal.name,
        meal.description.length > 50 ? meal.description.substring(0, 50) + '...' : meal.description,
        meal.price.toFixed(2)
      ]),
    });

    pdfDoc.save(`Menu_Report_${moment().format("YYYY_MM_DD")}.pdf`);
  };

  const toggleMealStatus = async (mealId: string, currentStatus: boolean) => {
    try {
      const mealRef = doc(db, "meals", mealId);
      await updateDoc(mealRef, {
        active: !currentStatus,
        updatedAt: Timestamp.now(),
      });
      toast.success(`Meal marked as ${!currentStatus ? "active" : "inactive"}`);
    } catch (err) {
      console.error(err);
      toast.error("Failed to update meal status");
    }
  };

  const handleImageSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setSelectedImage(file);
      const reader = new FileReader();
      reader.onload = () => setImagePreview(reader.result as string);
      reader.readAsDataURL(file);
    }
  };

  const uploadImage = async (file: File): Promise<string> => {
    try {
      const sanitizedName = file.name.replace(/[\r\n\t]/g, '').trim();
      const imageRef = ref(storage, `meals/${Date.now()}_${sanitizedName}`);
      const snapshot = await uploadBytes(imageRef, file);
      const url = await getDownloadURL(snapshot.ref);
      return url;
    } catch (error) {
      console.error("Upload error:", error);
      throw new Error("Failed to upload image");
    }
  };

  const handleAddMeal = async () => {
    if (!newMeal.name || !newMeal.description || !newMeal.price) {
      toast.error("Please fill in all fields");
      return;
    }
    
    setUploading(true);
    try {
      let imageUrl = "";
      if (selectedImage) {
        imageUrl = await uploadImage(selectedImage);
      }
      
      await addDoc(collection(db, "meals"), {
        name: newMeal.name,
        description: newMeal.description,
        price: parseFloat(newMeal.price),
        imageUrl,
        active: true,
        available: true,
        category: newMeal.category,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      });
      
      toast.success("Meal added successfully");
      setNewMeal({ name: "", description: "", price: "", category: "Main Dishes" });
      setSelectedImage(null);
      setImagePreview(null);
      setShowAddModal(false);
    } catch (err) {
      console.error(err);
      toast.error("Failed to add meal");
    } finally {
      setUploading(false);
    }
  };

  const handleEditMeal = async () => {
    if (!editingMeal) return;
    
    setUploading(true);
    try {
      let imageUrl = editingMeal.imageUrl;
      if (selectedImage) {
        imageUrl = await uploadImage(selectedImage);
      }
      
      const mealRef = doc(db, "meals", editingMeal.id);
      await updateDoc(mealRef, {
        name: editingMeal.name,
        description: editingMeal.description,
        price: editingMeal.price,
        imageUrl,
        category: editingMeal.category || "Main Dishes",
        updatedAt: Timestamp.now(),
      });
      
      toast.success("Meal updated successfully");
      setShowEditModal(false);
      setEditingMeal(null);
      setSelectedImage(null);
      setImagePreview(null);
    } catch (err) {
      console.error(err);
      toast.error("Failed to update meal");
    } finally {
      setUploading(false);
    }
  };

  const handleDeleteMeal = async (mealId: string) => {
    if (!confirm("Are you sure you want to delete this meal?")) return;
    try {
      await deleteDoc(doc(db, "meals", mealId));
      toast.success("Meal deleted successfully");
    } catch (err) {
      console.error(err);
      toast.error("Failed to delete meal");
    }
  };

  const toggleAvailability = async (mealId: string, currentAvailability: boolean) => {
    try {
      const mealRef = doc(db, "meals", mealId);
      await updateDoc(mealRef, {
        available: !currentAvailability,
        updatedAt: Timestamp.now(),
      });
      toast.success(`Meal marked as ${!currentAvailability ? "available" : "unavailable"}`);
    } catch (err) {
      console.error(err);
      toast.error("Failed to update meal availability");
    }
  };

  const handleBulkAction = async (action: string) => {
    if (selectedMeals.length === 0) {
      toast.error("Please select meals first");
      return;
    }

    try {
      const promises = selectedMeals.map(mealId => {
        const mealRef = doc(db, "meals", mealId);
        switch (action) {
          case 'available':
            return updateDoc(mealRef, { available: true, updatedAt: Timestamp.now() });
          case 'unavailable':
            return updateDoc(mealRef, { available: false, updatedAt: Timestamp.now() });
          case 'active':
            return updateDoc(mealRef, { active: true, updatedAt: Timestamp.now() });
          case 'inactive':
            return updateDoc(mealRef, { active: false, updatedAt: Timestamp.now() });
          case 'delete':
            return deleteDoc(doc(db, "meals", mealId));
          default:
            return Promise.resolve();
        }
      });
      
      await Promise.all(promises);
      toast.success(`Bulk action completed for ${selectedMeals.length} meals`);
      setSelectedMeals([]);
      setShowBulkActions(false);
    } catch (err) {
      console.error(err);
      toast.error("Failed to perform bulk action");
    }
  };

  const handleSelectAll = () => {
    if (selectedMeals.length === filteredMeals.length) {
      setSelectedMeals([]);
    } else {
      setSelectedMeals(filteredMeals.map(m => m.id));
    }
  };

  const duplicateMeal = async (meal: Meal) => {
    try {
      await addDoc(collection(db, "meals"), {
        name: `${meal.name} (Copy)`,
        description: meal.description,
        price: meal.price,
        imageUrl: meal.imageUrl || "",
        category: meal.category || "Main Dishes",
        active: false,
        available: true,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      });
      toast.success("Meal duplicated successfully");
    } catch (err) {
      console.error(err);
      toast.error("Failed to duplicate meal");
    }
  };

  const toggleRestaurantStatus = async () => {
    try {
      await setDoc(doc(db, "settings", "restaurant"), {
        isOpen: !restaurantOpen,
        updatedAt: Timestamp.now(),
      }, { merge: true });
      setRestaurantOpen(!restaurantOpen);
      toast.success(`Restaurant ${!restaurantOpen ? "opened" : "closed"}`);
    } catch (err) {
      console.error(err);
      toast.error("Failed to update restaurant status");
    }
  };

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Menu Management</h1>
        <p className="text-gray-600">Manage your restaurant's menu items and pricing.</p>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-6">
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Total Meals</p>
              <p className="text-2xl font-bold text-gray-900">{totalMeals}</p>
            </div>
            <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
              <Plus className="w-6 h-6 text-blue-600" />
            </div>
          </div>
        </div>
        
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Available</p>
              <p className="text-2xl font-bold text-green-600">{availableMeals}</p>
            </div>
            <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
              <CheckCircle className="w-6 h-6 text-green-600" />
            </div>
          </div>
        </div>
        
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Unavailable</p>
              <p className="text-2xl font-bold text-red-600">{unavailableMeals}</p>
            </div>
            <div className="w-12 h-12 bg-red-100 rounded-lg flex items-center justify-center">
              <XCircle className="w-6 h-6 text-red-600" />
            </div>
          </div>
        </div>
        
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Avg Price</p>
              <p className="text-2xl font-bold text-gray-900">${avgPrice.toFixed(2)}</p>
            </div>
            <div className="w-12 h-12 bg-yellow-100 rounded-lg flex items-center justify-center">
              <span className="text-yellow-600 font-bold text-lg">$</span>
            </div>
          </div>
        </div>
      </div>

      {/* Analytics Section */}
      {mealAnalytics.length > 0 && (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-6">
          <h2 className="text-xl font-semibold text-gray-900 mb-4">Meal Analytics</h2>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Most Ordered */}
            <div>
              <h3 className="text-lg font-medium text-gray-900 mb-3 flex items-center gap-2">
                <TrendingUp className="w-5 h-5 text-blue-600" />
                Most Ordered Meals
              </h3>
              <div className="space-y-2">
                {mealAnalytics.slice(0, 5).map((meal, index) => (
                  <div key={meal.name} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                    <div className="flex items-center gap-3">
                      <span className="w-6 h-6 bg-blue-100 text-blue-600 rounded-full flex items-center justify-center text-sm font-bold">
                        {index + 1}
                      </span>
                      <span className="font-medium text-gray-900">{meal.name}</span>
                    </div>
                    <span className="text-sm font-medium text-gray-600">{meal.totalOrders} orders</span>
                  </div>
                ))}
              </div>
            </div>
            
            {/* Top Revenue */}
            <div>
              <h3 className="text-lg font-medium text-gray-900 mb-3 flex items-center gap-2">
                <DollarSign className="w-5 h-5 text-green-600" />
                Top Revenue Meals
              </h3>
              <div className="space-y-2">
                {mealAnalytics
                  .sort((a, b) => b.totalRevenue - a.totalRevenue)
                  .slice(0, 5)
                  .map((meal, index) => (
                    <div key={meal.name} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                      <div className="flex items-center gap-3">
                        <span className="w-6 h-6 bg-green-100 text-green-600 rounded-full flex items-center justify-center text-sm font-bold">
                          {index + 1}
                        </span>
                        <span className="font-medium text-gray-900">{meal.name}</span>
                      </div>
                      <span className="text-sm font-medium text-gray-600">${meal.totalRevenue.toFixed(2)}</span>
                    </div>
                  ))
                }
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Search and Filters */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-6">
        <div className="flex flex-col lg:flex-row gap-4 items-start lg:items-center justify-between">
          <div className="flex flex-col sm:flex-row gap-4 flex-1">
            <div className="relative flex-1 max-w-md">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
              <input
                type="text"
                placeholder="Search meals..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors"
              />
            </div>
            
            <div className="flex items-center gap-2">
              <Filter className="text-gray-400 w-5 h-5" />
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value as "all" | "active" | "inactive")}
                className="border border-gray-300 px-3 py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors"
              >
                <option value="all">All Items</option>
                <option value="active">Active Only</option>
                <option value="inactive">Inactive Only</option>
              </select>
            </div>
            
            <div className="flex items-center gap-2">
              <CheckCircle className="text-gray-400 w-5 h-5" />
              <select
                value={availabilityFilter}
                onChange={(e) => setAvailabilityFilter(e.target.value as "all" | "available" | "unavailable")}
                className="border border-gray-300 px-3 py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors"
              >
                <option value="all">All Availability</option>
                <option value="available">Available</option>
                <option value="unavailable">Unavailable</option>
              </select>
            </div>
            
            <div className="flex items-center gap-2">
              <Filter className="text-gray-400 w-5 h-5" />
              <select
                value={categoryFilter}
                onChange={(e) => setCategoryFilter(e.target.value)}
                className="border border-gray-300 px-3 py-2 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors"
              >
                <option value="all">All Categories</option>
                {CATEGORIES.map(cat => (
                  <option key={cat} value={cat}>{cat}</option>
                ))}
              </select>
            </div>
          </div>
          
          <div className="flex gap-3">
            <button
              onClick={toggleRestaurantStatus}
              className={`px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200 shadow-sm ${
                restaurantOpen 
                  ? "bg-red-600 text-white hover:bg-red-700" 
                  : "bg-green-600 text-white hover:bg-green-700"
              }`}
            >
              {restaurantOpen ? "Close Restaurant" : "Open Restaurant"}
            </button>
            <button
              onClick={exportMealsToPDF}
              className="bg-green-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-green-700 transition-all duration-200 shadow-sm"
            >
              Export Menu
            </button>
            <button 
              onClick={() => setShowAddModal(true)}
              className="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700 transition-all duration-200 shadow-sm flex items-center gap-2"
            >
              <Plus className="w-4 h-4" />
              Add Meal
            </button>
          </div>
        </div>
      </div>

      {/* Bulk Actions */}
      {selectedMeals.length > 0 && (
        <div className="bg-blue-50 border border-blue-200 rounded-xl p-4 mb-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <span className="text-sm font-medium text-blue-900">
                {selectedMeals.length} meal(s) selected
              </span>
              <button
                onClick={() => setSelectedMeals([])}
                className="text-sm text-blue-600 hover:text-blue-800"
              >
                Clear selection
              </button>
            </div>
            <div className="flex gap-2">
              <button
                onClick={() => handleBulkAction('available')}
                className="px-3 py-1 bg-green-600 text-white text-sm rounded hover:bg-green-700"
              >
                Mark Available
              </button>
              <button
                onClick={() => handleBulkAction('unavailable')}
                className="px-3 py-1 bg-red-600 text-white text-sm rounded hover:bg-red-700"
              >
                Mark Unavailable
              </button>
              <button
                onClick={() => handleBulkAction('active')}
                className="px-3 py-1 bg-blue-600 text-white text-sm rounded hover:bg-blue-700"
              >
                Activate
              </button>
              <button
                onClick={() => handleBulkAction('inactive')}
                className="px-3 py-1 bg-gray-600 text-white text-sm rounded hover:bg-gray-700"
              >
                Deactivate
              </button>
              <button
                onClick={() => {
                  if (confirm(`Delete ${selectedMeals.length} selected meals?`)) {
                    handleBulkAction('delete');
                  }
                }}
                className="px-3 py-1 bg-red-600 text-white text-sm rounded hover:bg-red-700"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Results Summary */}
      <div className="mb-4">
        <p className="text-sm text-gray-600">
          Showing {filteredMeals.length} of {meals.length} meals
        </p>
      </div>

      {loading ? (
        <div className="flex justify-center items-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
        </div>
      ) : error ? (
        <div className="bg-red-50 border border-red-200 rounded-xl p-6 text-center">
          <p className="text-red-600 font-medium">Error loading meals: {error.message}</p>
        </div>
      ) : filteredMeals.length === 0 ? (
        <div className="bg-gray-50 border border-gray-200 rounded-xl p-12 text-center">
          <p className="text-gray-600 text-lg font-medium mb-2">No meals found</p>
        </div>
      ) : (
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    <input
                      type="checkbox"
                      checked={selectedMeals.length === filteredMeals.length && filteredMeals.length > 0}
                      onChange={handleSelectAll}
                      className="rounded border-gray-300"
                    />
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Image</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Category</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Description</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Price</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Availability</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Created</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {filteredMeals.map((meal) => (
                  <tr key={meal.id} className="hover:bg-gray-50 transition-colors duration-150">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <input
                        type="checkbox"
                        checked={selectedMeals.includes(meal.id)}
                        onChange={(e) => {
                          if (e.target.checked) {
                            setSelectedMeals([...selectedMeals, meal.id]);
                          } else {
                            setSelectedMeals(selectedMeals.filter(id => id !== meal.id));
                          }
                        }}
                        className="rounded border-gray-300"
                      />
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="w-12 h-12 rounded-lg overflow-hidden">
                        {meal.imageUrl ? (
                          <img 
                            src={meal.imageUrl.replace(/&amp;/g, '&')}
                            alt={meal.name}
                            className="w-full h-full object-cover"
                          />
                        ) : (
                          <div className="w-full h-full bg-gray-200 flex items-center justify-center">
                            <ImageIcon className="w-6 h-6 text-gray-400" />
                          </div>
                        )}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm font-medium text-gray-900">{meal.name}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                        {meal.category || 'Main Dishes'}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-sm text-gray-900 max-w-xs truncate" title={meal.description}>
                        {meal.description}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm font-medium text-gray-900">${meal.price.toFixed(2)}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <button
                        onClick={() => toggleAvailability(meal.id, meal.available !== false)}
                        className={`inline-flex items-center gap-2 px-3 py-1 rounded-full text-sm font-medium transition-colors ${
                          meal.available !== false
                            ? 'bg-green-100 text-green-800 hover:bg-green-200'
                            : 'bg-red-100 text-red-800 hover:bg-red-200'
                        }`}
                      >
                        {meal.available !== false ? (
                          <CheckCircle className="w-4 h-4" />
                        ) : (
                          <XCircle className="w-4 h-4" />
                        )}
                        {meal.available !== false ? 'Available' : 'Unavailable'}
                      </button>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <label className="inline-flex items-center cursor-pointer">
                        <input
                          type="checkbox"
                          checked={meal.active}
                          onChange={() => toggleMealStatus(meal.id, meal.active)}
                          className="sr-only peer"
                        />
                        <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-2 peer-focus:ring-blue-400 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-500 relative"></div>
                      </label>
                      <span className={`ml-3 text-xs font-medium ${
                        meal.active ? 'text-green-600' : 'text-gray-500'
                      }`}>
                        {meal.active ? 'Active' : 'Inactive'}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {meal.createdAt?.seconds
                        ? moment(meal.createdAt.seconds * 1000).format("MMM D, YYYY")
                        : "—"}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                      <div className="flex items-center gap-2">
                        <button 
                          onClick={() => {
                            setEditingMeal(meal);
                            setShowEditModal(true);
                          }}
                          className="text-blue-600 hover:text-blue-800 transition-colors duration-150 inline-flex items-center gap-1"
                        >
                          <Edit className="w-4 h-4" />
                          Edit
                        </button>
                        <button 
                          onClick={() => duplicateMeal(meal)}
                          className="text-green-600 hover:text-green-800 transition-colors duration-150 inline-flex items-center gap-1"
                        >
                          <Copy className="w-4 h-4" />
                          Duplicate
                        </button>
                        <button 
                          onClick={() => handleDeleteMeal(meal.id)}
                          className="text-red-600 hover:text-red-800 transition-colors duration-150 inline-flex items-center gap-1"
                        >
                          <Trash2 className="w-4 h-4" />
                          Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Add Meal Modal */}
      {showAddModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex justify-center items-center backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-2xl p-8 w-full max-w-md border border-gray-200 m-4">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-xl font-bold text-gray-900">Add New Meal</h2>
              <button
                onClick={() => setShowAddModal(false)}
                className="text-gray-400 hover:text-gray-600 transition-colors"
              >
                <X className="w-6 h-6" />
              </button>
            </div>
            
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Image</label>
                <div className="flex items-center space-x-4">
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handleImageSelect}
                    className="hidden"
                    id="image-upload"
                  />
                  <label
                    htmlFor="image-upload"
                    className="cursor-pointer flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                  >
                    <Upload className="w-4 h-4" />
                    Choose Image
                  </label>
                  {imagePreview && (
                    <img src={imagePreview} alt="Preview" className="w-16 h-16 rounded-lg object-cover" />
                  )}
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Name</label>
                <input
                  type="text"
                  value={newMeal.name}
                  onChange={(e) => setNewMeal({...newMeal, name: e.target.value})}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  placeholder="Enter meal name"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Description</label>
                <textarea
                  value={newMeal.description}
                  onChange={(e) => setNewMeal({...newMeal, description: e.target.value})}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  rows={3}
                  placeholder="Enter meal description"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Price ($)</label>
                <input
                  type="number"
                  step="0.01"
                  value={newMeal.price}
                  onChange={(e) => setNewMeal({...newMeal, price: e.target.value})}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  placeholder="0.00"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Category</label>
                <select
                  value={newMeal.category}
                  onChange={(e) => setNewMeal({...newMeal, category: e.target.value})}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                >
                  {CATEGORIES.map(cat => (
                    <option key={cat} value={cat}>{cat}</option>
                  ))}
                </select>
              </div>
            </div>
            
            <div className="flex justify-end gap-3 mt-8">
              <button
                onClick={() => setShowAddModal(false)}
                className="px-4 py-2 text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleAddMeal}
                disabled={uploading}
                className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 flex items-center gap-2"
              >
                {uploading && <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>}
                {uploading ? "Adding..." : "Add Meal"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Edit Meal Modal */}
      {showEditModal && editingMeal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex justify-center items-center backdrop-blur-sm">
          <div className="bg-white rounded-2xl shadow-2xl p-8 w-full max-w-md border border-gray-200 m-4">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-xl font-bold text-gray-900">Edit Meal</h2>
              <button
                onClick={() => {
                  setShowEditModal(false);
                  setEditingMeal(null);
                  setSelectedImage(null);
                  setImagePreview(null);
                }}
                className="text-gray-400 hover:text-gray-600 transition-colors"
              >
                <X className="w-6 h-6" />
              </button>
            </div>
            
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Image</label>
                <div className="flex items-center space-x-4">
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handleImageSelect}
                    className="hidden"
                    id="edit-image-upload"
                  />
                  <label
                    htmlFor="edit-image-upload"
                    className="cursor-pointer flex items-center gap-2 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                  >
                    <Upload className="w-4 h-4" />
                    Change Image
                  </label>
                  {editingMeal.imageUrl || imagePreview ? (
                    <img src={imagePreview || editingMeal.imageUrl} alt="Preview" className="w-16 h-16 rounded-lg object-cover" />
                  ) : (
                    <div className="w-16 h-16 rounded-lg border flex items-center justify-center bg-gray-100">
                      <ImageIcon className="w-6 h-6 text-gray-400" />
                    </div>
                  )}
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Name</label>
                <input
                  type="text"
                  value={editingMeal.name}
                  onChange={(e) => setEditingMeal({...editingMeal, name: e.target.value})}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Description</label>
                <textarea
                  value={editingMeal.description}
                  onChange={(e) => setEditingMeal({...editingMeal, description: e.target.value})}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                  rows={3}
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Price ($)</label>
                <input
                  type="number"
                  step="0.01"
                  value={editingMeal.price}
                  onChange={(e) => setEditingMeal({...editingMeal, price: parseFloat(e.target.value) || 0})}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">Category</label>
                <select
                  value={editingMeal.category || "Main Dishes"}
                  onChange={(e) => setEditingMeal({...editingMeal, category: e.target.value})}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                >
                  {CATEGORIES.map(cat => (
                    <option key={cat} value={cat}>{cat}</option>
                  ))}
                </select>
              </div>
            </div>
            
            <div className="flex justify-end gap-3 mt-8">
              <button
                onClick={() => {
                  setShowEditModal(false);
                  setEditingMeal(null);
                  setSelectedImage(null);
                  setImagePreview(null);
                }}
                className="px-4 py-2 text-gray-700 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleEditMeal}
                disabled={uploading}
                className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 flex items-center gap-2"
              >
                {uploading && <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>}
                {uploading ? "Updating..." : "Update Meal"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}