import { supabase } from './supabase'

/**
 * Add-ons and requests a dish can be ordered with — "Extra Shito +$1.99",
 * "No Coleslaw", "Stew on the Side" — as the restaurant listed them.
 *
 * One list per dish (base_slug), shared by all of its protein or soup
 * options. They live in the meal_modifiers table, and the server prices them
 * from there (see cartPricing.ts). Nothing in the browser is trusted for money.
 */
export interface Modifier {
  id: string
  baseSlug: string
  name: string
  price: number
  /** extra: something added, usually paid. request: a free change. */
  kind: 'extra' | 'request'
  hideWhenVegetarian: boolean
  position: number
}

/** A choice as recorded on a cart line or an order line, priced at the time. */
export interface ChosenModifier {
  id: string
  name: string
  price: number
}

export async function fetchModifiers(): Promise<Modifier[]> {
  const { data, error } = await supabase
    .from('meal_modifiers')
    .select('id, base_slug, name, price, kind, hide_when_vegetarian, position')
    .eq('active', true)
    .order('position')
  if (error || !data) return []
  return data.map((r: {
    id: string
    base_slug: string
    name: string
    price: number | string
    kind: 'extra' | 'request'
    hide_when_vegetarian: boolean
    position: number
  }) => ({
    id: r.id,
    baseSlug: r.base_slug,
    name: r.name,
    price: Number(r.price),
    kind: r.kind,
    hideWhenVegetarian: r.hide_when_vegetarian,
    position: r.position
  }))
}

/** What is offered for one option of a dish. */
export function modifiersFor(
  all: Modifier[],
  meal: { baseSlug: string; isVegetarian: boolean }
): Modifier[] {
  return all.filter(
    m => m.baseSlug === meal.baseSlug && !(meal.isVegetarian && m.hideWhenVegetarian)
  )
}

/** "Extra Shito", "No Shito" and "Shito on the Side" are all about shito. */
function subjectOf(name: string): string {
  return name
    .replace(/^(extra|no)\s+/i, '')
    .replace(/\s+on the side$/i, '')
    .trim()
    .toLowerCase()
}

const isWithout = (name: string) => /^no\s/i.test(name)

/**
 * Ticks or unticks one choice. "No Shito" can't stand alongside "Extra Shito"
 * or "Shito on the Side", so ticking one side of that clears the other.
 */
export function toggleModifier(selected: string[], mod: Modifier, offered: Modifier[]): string[] {
  if (selected.includes(mod.id)) return selected.filter(id => id !== mod.id)
  const subject = subjectOf(mod.name)
  const clashing = new Set(
    offered
      .filter(o =>
        o.id !== mod.id &&
        subjectOf(o.name) === subject &&
        isWithout(o.name) !== isWithout(mod.name))
      .map(o => o.id)
  )
  return [...selected.filter(id => !clashing.has(id)), mod.id]
}

/**
 * A cart line's identity: the same dish with the same choices and note is
 * one line, and anything different is its own. A plain dish keys as its bare
 * id, which is also what every cart saved before add-ons existed uses.
 */
export function lineKey(mealId: string, modifierIds: string[] = [], notes = ''): string {
  let key = mealId
  if (modifierIds.length) key += '|m:' + [...modifierIds].sort().join(',')
  const note = notes.trim().toLowerCase()
  if (note) key += '|n:' + note
  return key
}

export const keyOf = (item: { id: string; lineKey?: string }) => item.lineKey ?? item.id

/** "Extra Shito, No Coleslaw · Note: well done" — one line under the dish. */
export function lineDetail(
  mods?: { name: string }[] | null,
  notes?: string | null
): string {
  return [
    (mods ?? []).map(m => m.name).join(', '),
    notes ? `Note: ${notes}` : ''
  ].filter(Boolean).join(' · ')
}
