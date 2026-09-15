import type { SupabaseClient } from '@supabase/supabase-js'
import type { ChosenModifier } from './modifiers'

/**
 * Prices a cart from the database: each dish, and each add-on chosen for it.
 *
 * The one place this happens. create-payment-intent uses it for what is
 * charged and create-order for what is recorded, so the two can't drift
 * apart. The browser only says which dish, which add-ons and how many —
 * never a price.
 */

export interface CartItemInput {
  id: string
  quantity: number
  modifierIds?: string[]
  notes?: string | null
}

export interface PricedLine {
  id: string
  name: string
  quantity: number
  basePrice: number
  modifiers: ChosenModifier[]
  notes: string | null
  /** The dish plus its add-ons, per unit. */
  unitPrice: number
}

export type PriceResult =
  | { ok: true; lines: PricedLine[]; subtotal: number }
  | { ok: false; error: string }

const round2 = (n: number) => Math.round(n * 100) / 100
const MAX_NOTE = 200

export async function priceCart(db: SupabaseClient, items: CartItemInput[]): Promise<PriceResult> {
  if (!Array.isArray(items) || items.length === 0) {
    return { ok: false, error: 'Cart is empty' }
  }
  for (const item of items) {
    const badModifiers =
      item?.modifierIds !== undefined &&
      (!Array.isArray(item.modifierIds) || item.modifierIds.some(id => typeof id !== 'string'))
    const badNotes = item?.notes != null && typeof item.notes !== 'string'
    if (!item?.id || !Number.isInteger(item.quantity) || item.quantity <= 0 || badModifiers || badNotes) {
      return { ok: false, error: 'Invalid cart item' }
    }
  }

  const { data: meals, error: mealsError } = await db
    .from('meals')
    .select('id, name, price, active, available, base_slug')
    .in('id', [...new Set(items.map(i => i.id))])
  if (mealsError) return { ok: false, error: 'Could not load the menu' }
  const mealsById = new Map((meals ?? []).map(m => [m.id, m]))

  const wanted = [...new Set(items.flatMap(i => i.modifierIds ?? []))]
  const modsById = new Map<string, { id: string; name: string; price: number; base_slug: string; active: boolean; position: number }>()
  if (wanted.length) {
    const { data: mods, error: modsError } = await db
      .from('meal_modifiers')
      .select('id, name, price, base_slug, active, position')
      .in('id', wanted)
    if (modsError) return { ok: false, error: 'Could not load the menu' }
    for (const m of mods ?? []) modsById.set(m.id, m)
  }

  const lines: PricedLine[] = []
  let subtotal = 0
  for (const item of items) {
    const meal = mealsById.get(item.id)
    if (!meal) return { ok: false, error: `Meal not found: ${item.id}` }
    if (!meal.active || !meal.available) {
      return { ok: false, error: `${meal.name} is no longer available.` }
    }

    const chosen = []
    for (const modId of new Set(item.modifierIds ?? [])) {
      const mod = modsById.get(modId)
      // A stale cart — the restaurant removed an option since it was added —
      // or an option belonging to another dish. Refused rather than dropped,
      // so nobody is charged for, or cooked, something they didn't choose.
      if (!mod || !mod.active || mod.base_slug !== (meal.base_slug ?? meal.id)) {
        return {
          ok: false,
          error: `An option on ${meal.name} has changed. Remove it from your cart and add it again.`
        }
      }
      chosen.push(mod)
    }
    // Kitchen order, not tap order, so tickets always read the same way.
    chosen.sort((a, b) => a.position - b.position)
    const modifiers: ChosenModifier[] = chosen.map(m => ({ id: m.id, name: m.name, price: Number(m.price) }))

    const notes = typeof item.notes === 'string' ? item.notes.trim().slice(0, MAX_NOTE) || null : null
    const unitPrice = round2(Number(meal.price) + modifiers.reduce((sum, m) => sum + m.price, 0))
    subtotal += unitPrice * item.quantity
    lines.push({
      id: meal.id,
      name: meal.name,
      quantity: item.quantity,
      basePrice: Number(meal.price),
      modifiers,
      notes,
      unitPrice
    })
  }

  return { ok: true, lines, subtotal: round2(subtotal) }
}
