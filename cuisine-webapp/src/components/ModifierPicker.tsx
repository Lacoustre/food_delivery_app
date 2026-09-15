'use client'

import { Check } from 'lucide-react'
import { toggleModifier, type Modifier } from '@/lib/modifiers'

/**
 * A dish's add-ons and requests, as rows to tick. Shared by the phone dish
 * sheet and the meal page, so the two can't drift apart. Renders nothing for
 * a dish without any.
 */
export function ModifierPicker({
  offered,
  selected,
  onChange,
  className = ''
}: {
  offered: Modifier[]
  selected: string[]
  onChange: (ids: string[]) => void
  className?: string
}) {
  if (!offered.length) return null

  const groups = [
    { title: 'Extras', mods: offered.filter(m => m.kind === 'extra') },
    { title: 'Preferences', mods: offered.filter(m => m.kind === 'request') }
  ].filter(g => g.mods.length)

  return (
    <div className={`space-y-4 ${className}`}>
      {groups.map(g => (
        <div key={g.title} role="group" aria-label={g.title}>
          <p className="text-[11px] font-semibold tracking-[0.12em] uppercase text-sand-500 mb-1.5">
            {g.title}
          </p>
          <div className="rounded-control border border-sand-200 bg-white divide-y divide-sand-200 overflow-hidden">
            {g.mods.map(m => {
              const on = selected.includes(m.id)
              return (
                <button
                  key={m.id}
                  type="button"
                  role="checkbox"
                  aria-checked={on}
                  onClick={() => onChange(toggleModifier(selected, m, offered))}
                  className="w-full flex items-center gap-3 px-3 py-3 text-left text-[15px] text-ink hover:bg-sand-50 active:bg-sand-100 transition-colors"
                >
                  <span
                    aria-hidden
                    className={`shrink-0 w-5 h-5 rounded-md border flex items-center justify-center transition-colors ${
                      on ? 'bg-ink border-ink' : 'bg-white border-sand-300'
                    }`}
                  >
                    {on && <Check className="w-3.5 h-3.5 text-sand-50" strokeWidth={3} />}
                  </span>
                  <span className="flex-1">{m.name}</span>
                  {m.price > 0 && (
                    <span className="text-sm text-sand-700 tabular-nums">+${m.price.toFixed(2)}</span>
                  )}
                </button>
              )
            })}
          </div>
        </div>
      ))}
    </div>
  )
}
