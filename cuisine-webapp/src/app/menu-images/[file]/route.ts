/**
 * Serves dish photos from tasteofafricancuisine.com instead of Supabase.
 *
 * Supabase Storage sends `x-robots-tag: none` with every file — noindex,
 * nofollow — so Google Images was forbidden from listing a single one of the
 * restaurant's own photos. Searching for the menu showed DoorDash's, Yelp's
 * and Menufyy's copies because ours were not allowed in at all.
 *
 * This fetches the same file and passes it on without that header, from the
 * restaurant's own domain, which is also the domain Google should credit.
 * Uploads through the admin panel are unchanged: photos still live in the
 * Supabase bucket, and this is only the address they are shown at.
 */
const BUCKET = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/storage/v1/object/public/meals`

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ file: string }> }
) {
  const { file } = await params

  // A bare filename only. Anything with a slash or a leading dot could reach
  // outside the bucket, so it is refused rather than cleaned up.
  if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(file)) {
    return new Response('Not found', { status: 404 })
  }

  const upstream = await fetch(`${BUCKET}/${file}`, { cache: 'no-store' })
  if (!upstream.ok || !upstream.body) {
    return new Response('Not found', { status: 404 })
  }

  const type = upstream.headers.get('content-type') ?? 'application/octet-stream'
  if (!type.startsWith('image/')) {
    return new Response('Not found', { status: 404 })
  }

  return new Response(upstream.body, {
    headers: {
      'Content-Type': type,
      // A day in the browser, a week at Vercel's edge. A replaced photo gets a
      // new filename, so nothing stale is ever served under an old name.
      'Cache-Control': 'public, max-age=86400, s-maxage=604800, stale-while-revalidate=86400',
    },
  })
}
