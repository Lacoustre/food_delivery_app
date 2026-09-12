'use client'

import { useState, useEffect, useRef } from 'react'
import { useRouter } from 'next/navigation'
import { User, Mail, Phone, MapPin, Save, ArrowLeft, Camera, Upload, X } from 'lucide-react'
import Link from 'next/link'
import { useAuth } from '@/lib/AuthContext'
import { authService } from '@/lib/auth'

export default function ProfilePage() {
  const { user, loading: authLoading, userProfile } = useAuth()
  const router = useRouter()
  const [loading, setLoading] = useState(false)
  const [uploadingPhoto, setUploadingPhoto] = useState(false)
  const [success, setSuccess] = useState(false)
  const [photoPreview, setPhotoPreview] = useState<string | null>(null)
  const [selectedFile, setSelectedFile] = useState<File | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)
  const [formData, setFormData] = useState({
    name: '',
    phone: '',
    address: ''
  })

  useEffect(() => {
    // Same as the cart: user is null until the session has been restored, so
    // redirecting on it alone signs the customer out of their own profile.
    if (authLoading) return

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
      if (userProfile.photoURL) {
        setPhotoPreview(userProfile.photoURL)
      }
    }
  }, [user, userProfile, router])

  const handlePhotoSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      if (file.size > 5 * 1024 * 1024) {
        alert('File size must be less than 5MB')
        return
      }
      setSelectedFile(file)
      const reader = new FileReader()
      reader.onload = () => setPhotoPreview(reader.result as string)
      reader.readAsDataURL(file)
    }
  }

  const uploadPhoto = async () => {
    if (!selectedFile || !user) return null

    setUploadingPhoto(true)
    try {
      return await authService.uploadAvatar(selectedFile)
    } catch (error) {
      console.error('Photo upload error:', error)
      throw new Error('Failed to upload photo')
    } finally {
      setUploadingPhoto(false)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!user) return

    setLoading(true)
    try {
      let photoURL = userProfile?.photoURL

      if (selectedFile) {
        photoURL = (await uploadPhoto()) ?? undefined
      }

      await authService.updateProfile({
        name: formData.name,
        phone: formData.phone,
        address: formData.address,
        ...(photoURL && { photoURL }),
      })
      
      setSuccess(true)
      setSelectedFile(null)
      setTimeout(() => setSuccess(false), 3000)
    } catch (error) {
      console.error('Error updating profile:', error)
      alert('Failed to update profile. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  const removePhoto = () => {
    setPhotoPreview(null)
    setSelectedFile(null)
    if (fileInputRef.current) {
      fileInputRef.current.value = ''
    }
  }

  if (!user) {
    return (
      <div className="min-h-screen bg-sand-100 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-4 border-gold"></div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-sand-100 relative overflow-hidden">
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
      <div className="bg-white/80 backdrop-blur-md shadow-card border-b border-gold-50">
        <div className="page-shell-narrow px-4 py-4">
          <div className="flex items-center gap-4">
            <Link href="/" className="p-3 hover:bg-gold-50 rounded-full transition-all duration-200">
              <ArrowLeft className="w-6 h-6 text-gold-600" />
            </Link>
            <div>
              <h1 className="font-display text-3xl bg-gold-600 bg-clip-text text-transparent">
                My Profile
              </h1>
              <p className="text-sand-700 font-medium">Manage your account information</p>
            </div>
          </div>
        </div>
      </div>

      <div className="page-shell-narrow px-4 py-8">
        <div className="bg-white/60 backdrop-blur-sm rounded-card shadow-card border border-gold-300 p-8">
          {/* Profile Photo Section */}
          <div className="text-center mb-8">
            <div className="relative inline-block">
              <div className="w-32 h-32 rounded-full overflow-hidden border-4 border-gold shadow-card mx-auto mb-4 bg-gold">
                {photoPreview ? (
                  <img 
                    src={photoPreview} 
                    alt="Profile" 
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="w-full h-full flex items-center justify-center">
                    <User className="w-16 h-16 text-white" />
                  </div>
                )}
              </div>
              
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                onChange={handlePhotoSelect}
                className="hidden"
              />
              
              <button
                type="button"
                onClick={() => fileInputRef.current?.click()}
                className="absolute bottom-2 right-2 bg-gold hover:bg-gold-600 text-white p-3 rounded-full shadow-card transition-all transform hover:scale-110"
              >
                <Camera className="w-5 h-5" />
              </button>
              
              {photoPreview && selectedFile && (
                <button
                  type="button"
                  onClick={removePhoto}
                  className="absolute top-0 right-0 bg-clay hover:bg-clay text-white p-2 rounded-full shadow-card transition-all"
                >
                  <X className="w-4 h-4" />
                </button>
              )}
            </div>
            
            <h2 className="font-display text-2xl text-ink">{userProfile?.name || 'User'}</h2>
            <p className="text-sand-700">{user.email}</p>
            
            {selectedFile && (
              <div className="mt-3 inline-flex items-center gap-2 bg-gold-50 text-gold-800 px-4 py-2 rounded-full text-sm font-medium">
                <Upload className="w-4 h-4" />
                New photo selected
              </div>
            )}
          </div>

          <form onSubmit={handleSubmit} className="space-y-6">
            <div>
              <label className="block text-sm font-bold text-ink-soft mb-2">
                <User className="w-4 h-4 inline mr-2" />
                Full Name
              </label>
              <input
                type="text"
                value={formData.name}
                onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
                className="w-full p-4 border-2 border-gold-300 rounded-card focus:ring-4 focus:ring-orange-100 focus:border-gold outline-none bg-white text-ink"
                placeholder="Enter your full name"
                required
              />
            </div>

            <div>
              <label className="block text-sm font-bold text-ink-soft mb-2">
                <Mail className="w-4 h-4 inline mr-2" />
                Email Address
              </label>
              <input
                type="email"
                value={user.email || ''}
                className="w-full p-4 border-2 border-sand-200 rounded-card bg-sand-100 text-sand-700"
                disabled
              />
              <p className="text-xs text-sand-500 mt-1">Email cannot be changed</p>
            </div>

            <div>
              <label className="block text-sm font-bold text-ink-soft mb-2">
                <Phone className="w-4 h-4 inline mr-2" />
                Phone Number
              </label>
              <input
                type="tel"
                value={formData.phone}
                onChange={(e) => setFormData(prev => ({ ...prev, phone: e.target.value }))}
                className="w-full p-4 border-2 border-gold-300 rounded-card focus:ring-4 focus:ring-orange-100 focus:border-gold outline-none bg-white text-ink"
                placeholder="(555) 123-4567"
              />
            </div>

            <div>
              <label className="block text-sm font-bold text-ink-soft mb-2">
                <MapPin className="w-4 h-4 inline mr-2" />
                Default Address
              </label>
              <textarea
                value={formData.address}
                onChange={(e) => setFormData(prev => ({ ...prev, address: e.target.value }))}
                className="w-full p-4 border-2 border-gold-300 rounded-card focus:ring-4 focus:ring-orange-100 focus:border-gold outline-none bg-white text-ink min-h-[100px]"
                placeholder="Enter your default delivery address"
                rows={3}
              />
            </div>

            <button
              type="submit"
              disabled={loading || uploadingPhoto}
              className="w-full bg-gold text-white py-4 rounded-card font-bold text-lg hover:bg-gold-600 transition-all shadow-card disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none flex items-center justify-center gap-2"
            >
              {loading || uploadingPhoto ? (
                <>
                  <div className="animate-spin rounded-full h-5 w-5 border-t-2 border-white"></div>
                  {uploadingPhoto ? 'Uploading Photo...' : 'Saving...'}
                </>
              ) : (
                <>
                  <Save className="w-5 h-5" />
                  Save Changes
                </>
              )}
            </button>

            {success && (
              <div className="bg-kente-50 border border-kente-50 rounded-card p-4 text-center">
                <p className="text-kente-800 font-medium">✓ Profile updated successfully!</p>
              </div>
            )}
          </form>
        </div>
      </div>
      </div>
    </div>
  )
}
