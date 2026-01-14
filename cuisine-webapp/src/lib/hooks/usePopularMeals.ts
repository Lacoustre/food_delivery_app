'use client'

import { useState, useEffect } from 'react'
import { collection, query, where, getDocs, limit } from 'firebase/firestore'
import { db } from '@/lib/firebase'
import { MenuItem } from '@/lib/types'

export function usePopularMeals() {
  const [meals, setMeals] = useState<MenuItem[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function fetchPopularMeals() {
      try {
        const mealsQuery = query(
          collection(db, 'meals'),
          where('active', '==', true),
          where('available', '==', true),
          limit(8)
        )
        
        const snapshot = await getDocs(mealsQuery)
        const mealsData = snapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data()
        })) as MenuItem[]
        
        setMeals(mealsData)
      } catch (error) {
        console.error('Error fetching meals:', error)
      } finally {
        setLoading(false)
      }
    }

    fetchPopularMeals()
  }, [])

  return { meals, loading }
}