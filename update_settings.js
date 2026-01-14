const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp({
  projectId: 'africancuisine-b8759'
});

const db = admin.firestore();

async function updateDeliverySettings() {
  try {
    await db.collection('settings').doc('restaurant').set({
      deliveryRadius: 15.0,
      deliveryFee: 3.99
    }, { merge: true });
    
    console.log('✅ Delivery settings updated successfully!');
    console.log('📍 Delivery radius: 15 miles');
    console.log('💰 Base delivery fee: $3.99');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error updating settings:', error);
    process.exit(1);
  }
}

updateDeliverySettings();