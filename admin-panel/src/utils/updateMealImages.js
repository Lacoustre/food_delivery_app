import { collection, getDocs, updateDoc, doc } from 'firebase/firestore';
import { db } from '../firebase';

const mealImages = {
  'Waakye': 'assets/images/waakye.png',
  'Beans & Plantain': 'assets/images/beans_plantain.png',
  'Jollof Rice': 'assets/images/jollof.png',
  'Banku & Okro Stew': 'assets/images/banku.png',
  'Rice Ball & Peanut Soup': 'assets/images/rice_ball.png',
  'Fried Rice': 'assets/images/fried_rice.png',
  'Fried Yam': 'assets/images/fried_yam.png',
  'Boiled Yam & Eggplant Stew': 'assets/images/boiled_yam.png',
  'Plantain & Spinach Stew': 'assets/images/plantain_kontomire.png',
  'Shito (Small Bottle)': 'assets/images/shito.png',
  'Shito (Medium Bottle)': 'assets/images/medium_shito.avif',
  'Shito (Large Bottle)': 'assets/images/large_shito.avif',
  'Sprite': 'assets/images/sprite.png',
  'Fufu & Light Soup': 'assets/images/fufu_and_light_soup.avif',
  'Coke': 'assets/images/coke.png',
  'Fanta': 'assets/images/fanta.png',
  'Pineapple Juice': 'assets/images/pineapple_drink.png',
  'Rice & Stew': 'assets/images/rice_and_stew.avif',
  'Bottle Water': 'assets/images/bottle_water.png',
  'Banku & Tilapia': 'assets/images/banku_tilapia.avif',
  'Sobolo': 'assets/images/sobolo.avif',
  'Rice & Spinach Stew': 'assets/images/rice_spinach.avif',
  'White Rice & Eggplant Stew': 'assets/images/white_eggplant_stew.avif',
  'Boiled Yam & Spinach Stew': 'assets/images/boiled_yam_spinach.avif',
  'Ghana Malt': 'assets/images/ghana_malt.png'
};

const updateMealImages = async () => {
  try {
    const snapshot = await getDocs(collection(db, 'meals'));
    
    for (const docSnapshot of snapshot.docs) {
      const data = docSnapshot.data();
      const mealName = data.name;
      const imageUrl = mealImages[mealName];
      
      if (imageUrl) {
        await updateDoc(doc(db, 'meals', docSnapshot.id), {
          imageUrl: imageUrl
        });
        console.log(`Updated ${mealName} with image: ${imageUrl}`);
      }
    }
    
    console.log('All meal images updated successfully!');
  } catch (error) {
    console.error('Error updating meal images:', error);
  }
};

export default updateMealImages;