import { collection, addDoc, serverTimestamp, getDocs, deleteDoc } from 'firebase/firestore';
import { getStorage, ref, uploadBytes } from 'firebase/storage';
import { db } from '../firebase';

const meals = [
  { name: 'Waakye', price: 19.00, description: 'Traditional Ghanaian rice and beans dish', active: true, imageUrl: '/assets/images/waakye.png', category: 'Main Dishes' },
  { name: 'Beans & Plantain', price: 19.00, description: 'Nutritious beans served with sweet plantain', active: true, imageUrl: '/assets/images/beans_plantain.png', category: 'Main Dishes' },
  { name: 'Jollof Rice', price: 18.00, description: 'Spiced rice dish popular across West Africa', active: true, imageUrl: '/assets/images/jollof.png', category: 'Main Dishes' },
  { name: 'Banku & Okro Stew', price: 18.00, description: 'Fermented corn dough with okra stew', active: true, imageUrl: '/assets/images/banku.png', category: 'Main Dishes' },
  { name: 'Rice Ball & Peanut Soup', price: 20.00, description: 'Rice balls served with rich peanut soup', active: true, imageUrl: '/assets/images/rice_ball.png', category: 'Main Dishes' },
  { name: 'Fried Rice', price: 19.00, description: 'Stir-fried rice with vegetables and spices', active: true, imageUrl: '/assets/images/fried_rice.png', category: 'Main Dishes' },
  { name: 'Fried Yam', price: 20.00, description: 'Crispy fried yam served with pepper sauce', active: true, imageUrl: '/assets/images/fried_yam.png', category: 'Main Dishes' },
  { name: 'Boiled Yam & Eggplant Stew', price: 23.00, description: 'Tender boiled yam with rich eggplant stew', active: true, imageUrl: '/assets/images/boiled_yam.png', category: 'Main Dishes' },
  { name: 'Plantain & Spinach Stew', price: 19.00, description: 'Sweet plantain with nutritious spinach stew', active: true, imageUrl: '/assets/images/plantain_kontomire.png', category: 'Main Dishes' },
  { name: 'Shito (Small Bottle)', price: 20.00, description: 'Traditional Ghanaian hot pepper sauce - small bottle', active: true, imageUrl: '/assets/images/shito.png', category: 'Side Dishes' },
  { name: 'Shito (Medium Bottle)', price: 38.00, description: 'Traditional Ghanaian hot pepper sauce - medium bottle', active: true, imageUrl: '/assets/images/medium_shito.avif', category: 'Side Dishes' },
  { name: 'Shito (Large Bottle)', price: 65.00, description: 'Traditional Ghanaian hot pepper sauce - large bottle', active: true, imageUrl: '/assets/images/large_shito.avif', category: 'Side Dishes' },
  { name: 'Sprite', price: 1.50, description: 'Refreshing lemon-lime soda', active: true, imageUrl: '/assets/images/sprite.png', category: 'Drinks' },
  { name: 'Fufu & Light Soup', price: 20.00, description: 'Traditional pounded cassava with light soup', active: true, imageUrl: '/assets/images/fufu_and_light_soup.avif', category: 'Main Dishes' },
  { name: 'Coke', price: 1.50, description: 'Classic Coca-Cola', active: true, imageUrl: '/assets/images/coke.png', category: 'Drinks' },
  { name: 'Fanta', price: 1.50, description: 'Orange flavored soda', active: true, imageUrl: '/assets/images/fanta.png', category: 'Drinks' },
  { name: 'Pineapple Juice', price: 4.00, description: 'Fresh pineapple juice', active: true, imageUrl: '/assets/images/pineapple_drink.png', category: 'Drinks' },
  { name: 'Rice & Stew', price: 18.00, description: 'Steamed rice with tomato-based stew', active: true, imageUrl: '/assets/images/rice_and_stew.avif', category: 'Main Dishes' },
  { name: 'Bottle Water', price: 1.50, description: 'Pure drinking water', active: true, imageUrl: '/assets/images/bottle_water.png', category: 'Drinks' },
  { name: 'Banku & Tilapia', price: 24.00, description: 'Fermented corn dough with grilled tilapia', active: true, imageUrl: '/assets/images/banku_tilapia.avif', category: 'Main Dishes' },
  { name: 'Sobolo', price: 4.00, description: 'Traditional hibiscus drink', active: true, imageUrl: '/assets/images/sobolo.avif', category: 'Drinks' },
  { name: 'Rice & Spinach Stew', price: 20.00, description: 'Steamed rice with nutritious spinach stew', active: true, imageUrl: '/assets/images/rice_spinach.avif', category: 'Main Dishes' },
  { name: 'White Rice & Eggplant Stew', price: 20.00, description: 'White rice with rich eggplant stew', active: true, imageUrl: '/assets/images/white_eggplant_stew.avif', category: 'Main Dishes' },
  { name: 'Boiled Yam & Spinach Stew', price: 23.00, description: 'Tender boiled yam with spinach stew', active: true, imageUrl: '/assets/images/boiled_yam_spinach.avif', category: 'Main Dishes' },
  { name: 'Ghana Malt', price: 4.00, description: 'Non-alcoholic malt beverage', active: true, imageUrl: '/assets/images/ghana_malt.png', category: 'Drinks' }
];

const autoInitializeMeals = async () => {
  try {
    const snapshot = await getDocs(collection(db, 'meals'));
    if (snapshot.empty) {
      console.log('No meals found, initializing with default meals...');
      for (const meal of meals) {
        await addDoc(collection(db, 'meals'), {
          ...meal,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        });
      }
      console.log('Default meals initialized successfully!');
    }
  } catch (error) {
    console.error('Error auto-initializing meals:', error);
  }
};

const initializeMeals = async () => {
  // Clear existing meals first
  const snapshot = await getDocs(collection(db, 'meals'));
  const deletePromises = snapshot.docs.map(doc => deleteDoc(doc.ref));
  await Promise.all(deletePromises);
  
  // Add new meals
  for (const meal of meals) {
    await addDoc(collection(db, 'meals'), {
      ...meal,
      available: true,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
  }
};

export { autoInitializeMeals };
export default initializeMeals;