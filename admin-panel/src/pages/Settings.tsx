import { useState, useEffect } from "react";
import { doc, updateDoc, getDoc, setDoc } from "firebase/firestore";
import { db } from "../firebase";
import { toast } from "react-toastify";
import Loader from "../components/Loader";

interface RestaurantSettings {
  isOpen: boolean;
  name: string;
  address: string;
  phone: string;
  email: string;
  latitude: number;
  longitude: number;
  businessHours: {
    [key: string]: { open: string; close: string; closed: boolean };
  };
  deliveryFee: number;
  deliveryRadius: number;
  taxRate: number;
}

const defaultSettings: RestaurantSettings = {
  isOpen: true,
  name: "Taste of African Cuisine",
  address: "32 Kenwood Dr, Vernon, CT, 06066",
  phone: "9294563215",
  email: "tasteofafricancuisine01@gmail.com",
  latitude: 41.8323,
  longitude: -72.500336,
  businessHours: {
    monday: { open: "11:00", close: "20:00", closed: true },
    tuesday: { open: "11:00", close: "20:00", closed: false },
    wednesday: { open: "11:00", close: "20:00", closed: false },
    thursday: { open: "11:00", close: "20:00", closed: false },
    friday: { open: "11:00", close: "20:00", closed: false },
    saturday: { open: "11:00", close: "20:00", closed: false },
    sunday: { open: "12:00", close: "20:00", closed: true },
  },
  deliveryFee: 3.99,
  deliveryRadius: 10,
  taxRate: 6.35,
};

export default function Settings() {
  const [settings, setSettings] = useState<RestaurantSettings>(defaultSettings);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    loadSettings();
  }, []);

  const loadSettings = async () => {
    try {
      const docRef = doc(db, "settings", "restaurant");
      const docSnap = await getDoc(docRef);
      
      if (docSnap.exists()) {
        setSettings({ ...defaultSettings, ...docSnap.data() });
      } else {
        await setDoc(docRef, defaultSettings);
      }
    } catch {
      toast.error("Failed to load settings");
    } finally {
      setLoading(false);
    }
  };

  const saveSettings = async () => {
    setSaving(true);
    try {
      const docRef = doc(db, "settings", "restaurant");
      await updateDoc(docRef, settings as Partial<RestaurantSettings>);
      toast.success("Settings saved successfully");
    } catch {
      toast.error("Failed to save settings");
    } finally {
      setSaving(false);
    }
  };

  const toggleRestaurant = async () => {
    const newStatus = !settings.isOpen;
    setSettings(prev => ({ ...prev, isOpen: newStatus }));
    
    try {
      const docRef = doc(db, "settings", "restaurant");
      await updateDoc(docRef, { isOpen: newStatus });
      toast.success(`Restaurant ${newStatus ? 'opened' : 'closed'}`);
    } catch {
      toast.error("Failed to update restaurant status");
      setSettings(prev => ({ ...prev, isOpen: !newStatus }));
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center items-center h-[70vh]">
        <Loader />
      </div>
    );
  }

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Restaurant Settings</h1>
        <p className="text-gray-600">Manage your restaurant configuration and business hours.</p>
      </div>

      {/* Restaurant Status */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-6">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-xl font-semibold text-gray-900 mb-2">Restaurant Status</h2>
            <p className="text-gray-600">Control whether customers can place orders</p>
          </div>
          <button
            onClick={toggleRestaurant}
            className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
              settings.isOpen ? 'bg-green-600' : 'bg-gray-200'
            }`}
          >
            <span
              className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                settings.isOpen ? 'translate-x-6' : 'translate-x-1'
              }`}
            />
          </button>
        </div>
        <div className="mt-4">
          <span className={`inline-flex items-center gap-2 px-3 py-1 rounded-full text-sm font-medium ${
            settings.isOpen ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
          }`}>
            <div className={`w-2 h-2 rounded-full ${settings.isOpen ? 'bg-green-500' : 'bg-red-500'}`} />
            {settings.isOpen ? 'Open for Orders' : 'Closed'}
          </span>
        </div>
      </div>

      {/* Restaurant Info */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-6">
        <h2 className="text-xl font-semibold text-gray-900 mb-4">Restaurant Information</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Restaurant Name</label>
            <input
              type="text"
              value={settings.name}
              onChange={(e) => setSettings(prev => ({ ...prev, name: e.target.value }))}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Phone Number</label>
            <input
              type="tel"
              value={settings.phone}
              onChange={(e) => setSettings(prev => ({ ...prev, phone: e.target.value }))}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
          <div className="md:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-2">Email</label>
            <input
              type="email"
              value={settings.email}
              onChange={(e) => setSettings(prev => ({ ...prev, email: e.target.value }))}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
          <div className="md:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-2">Address</label>
            <input
              type="text"
              value={settings.address}
              onChange={(e) => setSettings(prev => ({ ...prev, address: e.target.value }))}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
        </div>
      </div>

      {/* Business Hours */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-6">
        <h2 className="text-xl font-semibold text-gray-900 mb-4">Business Hours</h2>
        <div className="space-y-4">
          {Object.entries(settings.businessHours).map(([day, hours]) => (
            <div key={day} className="flex items-center gap-4">
              <div className="w-24">
                <span className="text-sm font-medium text-gray-700 capitalize">{day}</span>
              </div>
              <label className="flex items-center">
                <input
                  type="checkbox"
                  checked={!hours.closed}
                  onChange={(e) => setSettings(prev => ({
                    ...prev,
                    businessHours: {
                      ...prev.businessHours,
                      [day]: { ...hours, closed: !e.target.checked }
                    }
                  }))}
                  className="mr-2"
                />
                <span className="text-sm text-gray-600">Open</span>
              </label>
              {!hours.closed && (
                <>
                  <input
                    type="time"
                    value={hours.open}
                    onChange={(e) => setSettings(prev => ({
                      ...prev,
                      businessHours: {
                        ...prev.businessHours,
                        [day]: { ...hours, open: e.target.value }
                      }
                    }))}
                    className="border border-gray-300 rounded px-2 py-1 text-sm"
                  />
                  <span className="text-gray-500">to</span>
                  <input
                    type="time"
                    value={hours.close}
                    onChange={(e) => setSettings(prev => ({
                      ...prev,
                      businessHours: {
                        ...prev.businessHours,
                        [day]: { ...hours, close: e.target.value }
                      }
                    }))}
                    className="border border-gray-300 rounded px-2 py-1 text-sm"
                  />
                </>
              )}
              {hours.closed && (
                <span className="text-red-600 text-sm">Closed</span>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* Delivery Settings */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-6">
        <h2 className="text-xl font-semibold text-gray-900 mb-4">Delivery Settings</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Delivery Fee ($)</label>
            <input
              type="number"
              step="0.01"
              value={settings.deliveryFee}
              onChange={(e) => setSettings(prev => ({ ...prev, deliveryFee: parseFloat(e.target.value) || 0 }))}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Delivery Radius (miles)</label>
            <input
              type="number"
              value={settings.deliveryRadius}
              onChange={(e) => setSettings(prev => ({ ...prev, deliveryRadius: parseInt(e.target.value) || 0 }))}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Tax Rate (%)</label>
            <input
              type="number"
              step="0.01"
              value={settings.taxRate}
              onChange={(e) => setSettings(prev => ({ ...prev, taxRate: parseFloat(e.target.value) || 0 }))}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
        </div>
      </div>

      {/* Save Button */}
      <div className="flex justify-end">
        <button
          onClick={saveSettings}
          disabled={saving}
          className="bg-blue-600 text-white px-6 py-2 rounded-lg font-medium hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {saving ? "Saving..." : "Save Settings"}
        </button>
      </div>
    </div>
  );
}