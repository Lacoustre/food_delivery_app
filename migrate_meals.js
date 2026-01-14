const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = {
  "type": "service_account",
  "project_id": "africancuisine-b8759",
  "private_key_id": "your_private_key_id",
  "private_key": "your_private_key",
  "client_email": "your_client_email",
  "client_id": "your_client_id",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs"
};

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const meals = [
  {
    name: 'Waakye',
    price: 19.00,
    description: 'Traditional Ghanaian rice and beans dish',
    active: true,
    imageUrl: '',
    category: 'Main Dishes'
  },
  {
    name: 'Beans & Plantain',
    price: 19.00,
    description: 'Nutritious beans served with sweet plantain',
    active: true,
    imageUrl: '',
    category: 'Main Dishes'
  },
  {
    name: 'Jollof Rice',
    price: 18.00,
    description: 'Spiced rice dish popular across West Africa',
    active: true,
    imageUrl: '',
    category: 'Main Dishes'
  },
  {
    name: 'Banku & Okro Stew',
    price: 18.00,
    description: 'Fermented corn dough with okra stew',
    active: true,
    imageUrl: '',
    category: 'Main Dishes'
  },
  {
    name: 'Rice Ball & Peanut Soup',
    price: 20.00,
    description: 'Rice balls served with rich peanut soup',
    active: true,
    imageUrl: '',
    category: 'Main Dishes'
  },
  {
    name: 'Fried Rice',
    price: 19.00,
    description: 'Stir-fried rice with vegetables and spices',
    active: true,
    imageUrl: '',
    category: 'Main Dishes'
  },
  {
    name: 'Fried Yam',
    price: 20.00,
    description: 'Crispy fried yam served with pepper sauce',
    active: true,
    imageUrl: '',
    category: 'Main Dishes'
  },
  {
    name: 'Boiled Yam & Eggplant Stew',
    price: 23.00,
    description: 'Tender boiled yam with rich eggplant stew',
    active: true,
    imageUrl: '',
    category: 'Main Dishes'
  },
  {
    name: 'Plantain & Spinach Stew',
    price: 19.00,
    description: 'Sweet plantain with nutritious spinach stew',
    active: true,
    imageUrl: '',
    category: 'Main Dishes'
  },
  {
    name: 'Shito (Small Bottle)',
    price: 20.00,
    description: 'Traditional Ghanaian hot pepper sauce - small bottle',
    active: true,
    imageUrl: '',
    category: 'Side Dishes'
  },
  {
    name: 'Shito (Medium Bottle)',
    price: 38.00,
    description: 'Traditional Ghanaian hot pepper sauce - medium bottle',
    active: true,
    imageUrl: '',
    category: 'Side Dishes'
  },
  {
    name: 'Shito (Large Bottle)',
    price: 65.00,
    description: 'Traditional Ghanaian hot pepper sauce - large bottle',
    active: true,
    imageUrl: '',
    category: 'Side Dishes'
  },
  {
    name: 'Sprite',
    price: 1.50,
    description: 'Refreshing lemon-lime soda',
    active: true,
    imageUrl: '',
    category: 'Drinks'
  },
  {
    name: 'Fufu & Light Soup',
    price: 20.00,
    description: 'Traditional pounded cassava with light soup',
    active: true,
    imageUrl: '',
    category: 'Main Dishes'
  },
  {
    name: 'Coke',
    price: 1.50,
    description: 'Classic Coca-Cola',
    active: true,
    imageUrl: '',
    category: 'Drinks'
  },
  {
    name: 'Fanta',
    price: 1.50,
    description: 'Orange flavored soda',
    active: true,
    imageUrl: '',
    category: 'Drinks'
  },
  {
    name: 'Pineapple Juice',
    price: 4.00,
    description: 'Fresh pineapple juice',
    active: true,
    imageUrl: '',
    category: 'Drinks'
  },
  {
    name: 'Rice & Stew',
    price: 18.00,
    description: 'Steamed rice with tomato-based stew',
    active: true,
    imageUrl: '',
    category: 'Main Dishes'
  },
  {
    name: 'Bottle Water',
    price: 1.50,
    description: 'Pure drinking water',
    active: true,
    imageUrl: '',
    category: 'Drinks'
  },
  {
    name: 'Banku & Tilapia',
    price: 24.00,
    description: 'Fermented corn dough with grilled tilapia',
    active: true,
    imageUrl: '',
    category: 'Main Dishes'
  },
  {
    name: 'Sobolo',
    price: 4.00,
    description: 'Traditional hibiscus drink',
    active: true,
    imageUrl: '',
    category: 'Drinks'
  },
  {
    name: 'Rice & Spinach Stew',
    price: 20.00,
    description: 'Steamed rice with nutritious spinach stew',
    active: true,
    imageUrl: '',
    category: 'Main Dishes'
  },
  {
    name: 'White Rice & Eggplant Stew',
    price: 20.00,
    description: 'White rice with rich eggplant stew',
    active: true,
    imageUrl: '',
    category: 'Main Dishes'
  },
  {
    name: 'Boiled Yam & Spinach Stew',
    price: 23.00,
    description: 'Tender boiled yam with spinach stew',
    active: true,
    imageUrl: '',
    category: 'Main Dishes'
  },
  {
    name: 'Ghana Malt',
    price: 4.00,
    description: 'Non-alcoholic malt beverage',
    active: true,
    imageUrl: '',
    category: 'Drinks'
  }
];

async function migrateMeals() {
  console.log('Starting meal migration...');
  
  const batch = db.batch();
  
  meals.forEach((meal) => {
    const docRef = db.collection('meals').doc();
    batch.set(docRef, {
      ...meal,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });
  
  try {
    await batch.commit();
    console.log(`Successfully migrated ${meals.length} meals to Firebase!`);
  } catch (error) {
    console.error('Error migrating meals:', error);
  }
}

// Run migration
migrateMeals().then(() => {
  console.log('Migration complete!');
  process.exit(0);
});