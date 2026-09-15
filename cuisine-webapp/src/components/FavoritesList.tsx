'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { Heart } from 'lucide-react'
import { favoritesService } from '@/lib/favoritesService'
import { mealsService, type Meal } from '@/lib/mealsService'
import { mealImageSrc } from '@/lib/mealImage'
import { DishPhoto } from '@/components/DishPhoto'

const imageFor = (meal: Meal) => {
  if (!meal.imageUrl) return '/assets/images/logo.png'
  if (meal.imageUrl.startsWith('http')) return mealImageSrc(meal.imageUrl)
  if (meal.imageUrl.startsWith('/assets/')) return meal.imageUrl
  return `/assets/images/${meal.imageUrl}`
}

/**
 * The dishes a customer has hearted, on their profile.
 *
 * Hearts were saved to the favorites table from the menu, and then shown
 * nowhere, so tapping one did nothing a customer could see. A heart is saved
 * for the exact option ("Jollof with Grilled Chicken"), and that is what
 * opens from here.
 */
export function FavoritesList({ userId }: { userId: string }) {
  const [ids, setIds] = useState<Set<string> | null>(null)
  const [meals, setMeals] = useState<Meal[]>([])

  useEffect(() => favoritesService.onFavoritesChange(userId, setIds), [userId])
  useEffect(() => {
    mealsService.getAllMeals().then(setMeals)
  }, [])

  const loaded = ids !== null && meals.length > 0
  const saved = loaded
    ? meals.filter(m => ids.has(m.id)).sort((a, b) => a.name.localeCompare(b.name))
    : []

  // Arriving from "Favorites" in the menu: the section renders after sign-in
  // and the menu load, too late for the browser's own jump to #favorites.
  useEffect(() => {
    if (loaded && window.location.hash === '#favorites') {
      document.getElementById('favorites')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
    }
  }, [loaded])

  const unsave = (id: string) => {
    setIds(prev => {
      const next = new Set(prev)
      next.delete(id)
      return next
    })
    favoritesService.removeFavorite(userId, id)
  }

  return (
    <section
      id="favorites"
      className="mt-8 scroll-mt-6 bg-white/60 backdrop-blur-sm rounded-card shadow-card border border-gold-300 p-5 sm:p-8"
    >
      <h2 className="font-display text-2xl text-ink mb-5">Favorites</h2>

      {!loaded ? (
        <div className="flex justify-center py-8">
          <div className="w-7 h-7 border-2 border-sand-300 border-t-gold rounded-full animate-spin" />
        </div>
      ) : saved.length === 0 ? (
        <div className="text-center py-6">
          <p className="text-sand-700">No favorites yet.</p>
          <Link href="/#menu" className="inline-block mt-3 text-gold-600 font-semibold hover:underline">
            Browse the menu
          </Link>
        </div>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
          {saved.map(meal => {
            const offMenu = meal.active === false
            const soldOut = !offMenu && meal.available === false
            const body = (
              <>
                <div className="relative aspect-square overflow-hidden bg-sand-100">
                  <DishPhoto src={imageFor(meal)} alt={`${meal.name} at Taste of African Cuisine`} />
                  {(offMenu || soldOut) && (
                    <div className="absolute inset-0 bg-ink/60 flex items-center justify-center p-2">
                      <span className="bg-clay text-sand-50 px-2.5 py-1 rounded-control text-xs font-semibold text-center">
                        {offMenu ? 'No longer on the menu' : 'Sold out'}
                      </span>
                    </div>
                  )}
                </div>
                <div className="flex flex-col flex-1 p-3">
                  <span className="font-display text-base text-ink leading-tight line-clamp-2">{meal.name}</span>
                  <span className="mt-auto pt-2 text-sm font-semibold text-ink tabular-nums">${meal.price.toFixed(2)}</span>
                </div>
              </>
            )
            return (
              <div
                key={meal.id}
                data-favorite
                className="relative flex flex-col bg-white border border-sand-200 rounded-card overflow-hidden"
              >
                {offMenu ? (
                  <div className="flex flex-col flex-1 opacity-80">{body}</div>
                ) : (
                  <Link
                    href={`/meal?meal=${encodeURIComponent(JSON.stringify(meal))}`}
                    className="flex flex-col flex-1"
                  >
                    {body}
                  </Link>
                )}
                <button
                  onClick={() => unsave(meal.id)}
                  aria-label={`Remove ${meal.name} from favorites`}
                  className="absolute top-2 right-2 p-1.5 bg-sand-50/90 backdrop-blur rounded-full"
                >
                  <Heart className="w-4 h-4 fill-clay text-clay" />
                </button>
              </div>
            )
          })}
        </div>
      )}
    </section>
  )
}
