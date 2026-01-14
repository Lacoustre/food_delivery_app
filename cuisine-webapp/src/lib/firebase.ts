import { initializeApp } from 'firebase/app'
import { getFirestore } from 'firebase/firestore'
import { getAuth } from 'firebase/auth'
import { getStorage } from 'firebase/storage'

// Use the same Firebase config as the admin panel and mobile app
const firebaseConfig = {
  apiKey: "AIzaSyB_kltXeq8Jd7RE4mKC1niqbH6mhcs35_U",
  authDomain: "africancuisine-b8759.firebaseapp.com",
  projectId: "africancuisine-b8759",
  storageBucket: "africancuisine-b8759.firebasestorage.app",
  messagingSenderId: "367349792428",
  appId: "1:367349792428:web:87890f4c489af5b0706909"
}

const app = initializeApp(firebaseConfig)
export const db = getFirestore(app)
export const auth = getAuth(app)
export const storage = getStorage(app)