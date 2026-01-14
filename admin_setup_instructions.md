# Admin Setup Instructions

## Method 1: Firebase Console (Recommended)

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to Firestore Database
4. Navigate to the `admins` collection
5. Create a new document with your user ID as the document ID
6. Add a field: `role` with value `"admin"`

## Method 2: Using Firebase CLI (Advanced)

```javascript
// Run this in your browser console on the admin panel
import { doc, setDoc } from 'firebase/firestore';
import { getAuth } from 'firebase/auth';
import { db } from './firebase';

const auth = getAuth();
const user = auth.currentUser;

if (user) {
  await setDoc(doc(db, 'admins', user.uid), {
    role: 'admin',
    email: user.email,
    createdAt: new Date()
  });
  console.log('Admin role set successfully');
}
```

## Method 3: Temporary Admin Override

If you need immediate access, you can temporarily modify the Drivers.tsx component to bypass the admin check:

```typescript
// In Drivers.tsx, comment out the permission error check temporarily
// if (permError) {
//   return (
//     <div className="p-8">
//       <div className="bg-red-50 border border-red-200 text-red-800 rounded-xl p-6">
//         <p className="font-semibold mb-1">Permission denied</p>
//         <p className="text-sm">
//           Sign in as an admin (ensure <code>admins/&#123;uid&#125;.role</code> is <code>"admin"</code>).
//         </p>
//         <p className="text-xs mt-2 text-red-700/80">Error: {permError}</p>
//       </div>
//     </div>
//   );
// }
```

## Your Driver Management Features

Your admin panel already includes:

✅ **Real-time Updates** - Driver applications appear instantly
✅ **Status Filtering** - View pending, approved, or rejected drivers
✅ **Search Functionality** - Find drivers by name, email, or phone
✅ **Detailed Information** - View license numbers, vehicle types, etc.
✅ **One-Click Approval** - Approve or reject with single button click
✅ **Statistics Dashboard** - See counts of all driver statuses
✅ **Professional UI** - Clean, modern interface with proper styling

## Next Steps

1. Set your admin role using Method 1 above
2. Access the admin panel and approve your driver account
3. Refresh the driver app to access the main dashboard
4. Start using the driver app for deliveries!

The system is fully functional and ready to use.