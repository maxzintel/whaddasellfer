import type { Hello } from './types'

async function getJson<T>(path: string): Promise<T> {
  const res = await fetch(path)
  const body = await res.json()
  if (!res.ok) throw new Error(body.error ?? `Request failed: ${res.status}`)
  return body as T
}

export const getHello = () => getJson<Hello>('/api/hello')
