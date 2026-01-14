import { collection, getDocs, doc, updateDoc } from 'firebase/firestore'
import { db } from './firebase'

export const fixUndefinedCategories = async () => {
  try {
    console.log('Starting to fix undefined categories...')
    
    const mealsCollection = collection(db, 'meals')
    const mealsSnapshot = await getDocs(mealsCollection)
    
    const updates = []
    
    mealsSnapshot.docs.forEach(mealDoc => {
      const mealData = mealDoc.data()
      
      // Check if category is undefined, null, or empty
      if (!mealData.category || mealData.category === 'undefined') {
        // Default to 'Main Dishes' for meals without categories
        updates.push(
          updateDoc(doc(db, 'meals', mealDoc.id), {
            category: 'Main Dishes'
          })
        )
        console.log(`Updating meal ${mealDoc.id} (${mealData.name}) to Main Dishes`)
      }
    })
    
    // Execute all updates
    await Promise.all(updates)
    
    console.log(`Successfully updated ${updates.length} meals with undefined categories`)
    return { success: true, updatedCount: updates.length }
    
  } catch (error) {
    console.error('Error fixing categories:', error)
    return { success: false, error }
  }
}