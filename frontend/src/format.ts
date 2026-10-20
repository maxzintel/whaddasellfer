// Display helpers. Pure functions, no React.

const money = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  maximumFractionDigits: 0,
})
const integer = new Intl.NumberFormat('en-US')

export const formatMoney = (dollars: number): string => money.format(dollars)

export const formatMileage = (miles: number): string =>
  `${integer.format(miles)} ${miles === 1 ? 'mile' : 'miles'}`

export const formatPoints = (points: number): string => integer.format(points)

// pct_off is signed with one decimal: +13.0 means the guess was 13% high.
export function formatPctOff(pctOff: number): string {
  const abs = Math.abs(pctOff)
  if (abs < 0.05) return 'Spot on!'
  const shown = abs < 1 ? '<1' : String(Math.round(abs))
  return `${shown}% ${pctOff > 0 ? 'high' : 'low'}`
}

// "2026-10-20" -> "Tuesday, October 20, 2026". Formatted in UTC so the calendar date never shifts.
export function formatPuzzleDate(isoDate: string): string {
  const [y, m, d] = isoDate.split('-').map(Number)
  if (!y || !m || !d) return isoDate
  return new Intl.DateTimeFormat('en-US', { dateStyle: 'full', timeZone: 'UTC' }).format(
    new Date(Date.UTC(y, m - 1, d)),
  )
}

// ISO 8601 timestamp -> "Nov 24, 2025" (US Eastern, where the auctions close).
export function formatSoldDate(iso: string): string {
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return iso
  return new Intl.DateTimeFormat('en-US', { dateStyle: 'medium', timeZone: 'America/New_York' }).format(
    date,
  )
}

// Spec values arrive lowercase ("manual", "suv", "clean (ca)").
export function formatSpec(value: string): string {
  if (value.toLowerCase() === 'suv') return 'SUV'
  // Title status carries a state/province code: "clean (ca)" -> "Clean (CA)".
  const withCodes = value.replace(/\(([a-z]{2})\b/g, (_, code: string) => `(${code.toUpperCase()}`)
  return withCodes.charAt(0).toUpperCase() + withCodes.slice(1)
}

// "$25,000", "25000" and "25,000.00" all mean 25000: ignore any cents, then drop everything
// except digits. Returns null when there are no digits. ("25k" becomes 25; the live preview
// makes that obvious.)
export function parseGuess(input: string): number | null {
  const digits = input.split('.')[0].replace(/\D/g, '')
  if (digits === '') return null
  return Number(digits)
}

// Today's puzzle date (YYYY-MM-DD) in US Eastern, matching the server's clock.
export const easternToday = (now: Date = new Date()): string =>
  new Intl.DateTimeFormat('en-CA', { timeZone: 'America/New_York' }).format(now)
