import { initializeApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { getFirestore } from "firebase/firestore";

// Your actual Firebase config
const firebaseConfig = {
  apiKey: "AIzaSyB_kltXeq8Jd7RE4mKC1niqbH6mhcs35_U",
  authDomain: "africancuisine-b8759.firebaseapp.com",
  projectId: "africancuisine-b8759",
  storageBucket: "africancuisine-b8759.firebasestorage.app",
  messagingSenderId: "367349792428",
  appId: "1:367349792428:web:87890f4c489af5b0706909"
};

// Initialize Firebase App
const app = initializeApp(firebaseConfig);

// ✅ Export both Auth and Firestore
export const auth = getAuth(app);
export const db = getFirestore(app);
