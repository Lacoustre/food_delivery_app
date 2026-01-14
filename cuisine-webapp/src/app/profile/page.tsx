'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { User, Mail, Phone, MapPin, Save, ArrowLeft } from 'lucide-react'
import Link from 'next/link'
import { useAuth } from '@/lib/AuthContext'
import { doc, updateDoc } from 'firebase/firestore'
import { db } from '@/lib/firebase'

export default function ProfilePage() {
  const { user, userProfile } = useAuth()
  const router = useRouter()
  const [loading, setLoading] = useState(false)
  const [success, setSuccess] = useState(false)
  const [formData, setFormData] = useState({
    name: '',
    phone: '',
    address: ''
  })

  useEffect(() => {
    if (!user) {
      router.push('/login')
      return
    }
    
    if (userProfile) {
      setFormData({
        name: userProfile.name || '',
        phone: userProfile.phone || '',
        address: userProfile.address || ''
      })
    }
  }, [user, userProfile, router])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!user) return

    setLoading(true)
    try {
      await updateDoc(doc(db, 'users', user.uid), {
        name: formData.name,
        phone: formData.phone,
        address: formData.address,
        updatedAt: new Date()
      })
      
      setSuccess(true)
      setTimeout(() => setSuccess(false), 3000)
    } catch (error) {
      console.error('Error updating profile:', error)
      alert('Failed to update profile. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  if (!user) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-orange-50 to-amber-100 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-orange-500"></div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-orange-50 to-amber-100 relative overflow-hidden">
      {/* Background Logo */}
      <div className="fixed inset-0 flex items-center justify-center opacity-5 pointer-events-none z-0">
        <img 
          src="/assets/images/logo.png" 
          alt="Background Logo" 
          className="w-96 h-96 object-contain"
        />
      </div>
      
      <div className="relative z-10">
      {/* Header */}
      <div className="bg-white/80 backdrop-blur-md shadow-lg border-b border-orange-100">
        <div className="max-w-4xl mx-auto px-4 py-4">
          <div className="flex items-center gap-4">
            <Link href="/" className="p-3 hover:bg-orange-100 rounded-full transition-all duration-200">
              <ArrowLeft className="w-6 h-6 text-orange-600" />
            </Link>
            <div>
              <h1 className="text-3xl font-bold bg-gradient-to-r from-orange-600 to-red-600 bg-clip-text text-transparent">
                My Profile
              </h1>
              <p className="text-gray-700 font-medium">Manage your account information</p>
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-2xl mx-auto px-4 py-8">
        <div className="bg-white/60 backdrop-blur-sm rounded-3xl shadow-xl border border-orange-200 p-8">
          <div className="text-center mb-8">
            <div className="w-20 h-20 bg-gradient-to-br from-orange-500 to-red-500 rounded-full flex items-center justify-center mx-auto mb-4">
              <User className="w-10 h-10 text-white" />
            </div>
            <h2 className="text-2xl font-bold text-gray-900">{userProfile?.name || 'User'}</h2>
            <p className="text-gray-600">{user.email}</p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-6">
            <div>
              <label className="block text-sm font-bold text-gray-800 mb-2">
                <User className="w-4 h-4 inline mr-2" />
                Full Name
              </label>
              <input
                type="text"
                value={formData.name}
                onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
                className="w-full p-4 border-2 border-orange-200 rounded-2xl focus:ring-4 focus:ring-orange-100 focus:border-orange-500 outline-none bg-white text-gray-900"
                placeholder="Enter your full name"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-bold text-gray-800 mb-2">
                <Mail className="w-4 h-4 inline mr-2" />
                Email Address
              </label>
              <input
                type="email"
                value={user.email || ''}
                className="w-full p-4 border-2 border-gray-200 rounded-2xl bg-gray-100 text-gray-600"
                disabled
              />
              <p className="text-xs text-gray-500 mt-1">Email cannot be changed</p>
            </div>

            <div>
              <label className="block text-sm font-bold text-gray-800 mb-2">
                <Phone className="w-4 h-4 inline mr-2" />
                Phone Number
              </label>
              <input
                type="tel"
                value={formData.phone}
                onChange={(e) => setFormData(prev => ({ ...prev, phone: e.target.value }))}
                className="w-full p-4 border-2 border-orange-200 rounded-2xl focus:ring-4 focus:ring-orange-100 focus:border-orange-500 outline-none bg-white text-gray-900"
                placeholder="(555) 123-4567"
              />
            </div>

            <div>
              <label className="block text-sm font-bold text-gray-800 mb-2">
                <MapPin className="w-4 h-4 inline mr-2" />
                Default Address
              </label>
              <textarea
                value={formData.address}
                onChange={(e) => setFormData(prev => ({ ...prev, address: e.target.value }))}
                className="w-full p-4 border-2 border-orange-200 rounded-2xl focus:ring-4 focus:ring-orange-100 focus:border-orange-500 outline-none bg-white text-gray-900 min-h-[100px]"
                placeholder="Enter your default delivery address"
                rows={3}
              />
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-gradient-to-r from-orange-500 to-red-500 text-white py-4 rounded-2xl font-bold text-lg hover:from-orange-600 hover:to-red-600 transition-all transform hover:scale-105 shadow-lg disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none flex items-center justify-center gap-2"
            >
              {loading ? (
                <>
                  <div className="animate-spin rounded-full h-5 w-5 border-t-2 border-white"></div>
                  Saving...
                </>
              ) : (
                <>
                  <Save className="w-5 h-5" />
                  Save Changes
                </>
              )}
            </button>

            {success && (
              <div className="bg-green-50 border border-green-200 rounded-2xl p-4 text-center">
                <p className="text-green-800 font-medium">Profile updated successfully!</p>
              </div>
            )}
          </form>
        </div>
      </div>
      </div>
    </div>
  )
}
