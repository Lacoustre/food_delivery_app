'use client'

import { useEffect, useState } from 'react'
import { GRAND_OPENING, openingState } from '@/lib/grandOpening'

/**
 * The first thing a customer sees on opening day. It takes itself down when
 * the day is over, so nobody has to remember to remove it.
 */
export function GrandOpeningBanner() {
  // Decided after mount: the server renders this HTML ahead of time and has
  // no idea what day it will be read on, so deciding during render would
  // either cache the wrong answer or break hydration.
  const [state, setState] = useState<'before' | 'today' | 'over' | null>(null)

  useEffect(() => {
    const read = () => setState(openingState())
    read()
    const timer = setInterval(read, 60_000)
    return () => clearInterval(timer)
  }, [])

  if (state !== 'today' && state !== 'before') return null

  return (
    <div data-opening-banner className="bg-gold text-ink text-center px-4 py-2.5 text-[13px] sm:text-sm">
      <span className="font-bold tracking-tight">
        {state === 'today'
          ? `Grand opening · ${GRAND_OPENING.percent}% off every dish today`
          : `Grand opening tomorrow · ${GRAND_OPENING.percent}% off every dish`}
      </span>
      <span className="hidden sm:inline"> · online or in store</span>
    </div>
  )
}
