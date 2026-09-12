import { createClient } from "npm:@supabase/supabase-js@2";

/**
 * Pulls reviews from the Google Business Profile API into google_reviews.
 *
 * Reviews live on the v4 API. Google split the Business Profile APIs into
 * several newer services, but reviews were never moved, so this endpoint is
 * the only way to read them:
 *
 *   GET https://mybusiness.googleapis.com/v4/{location}/reviews
 *
 * Access has to be granted by hand — enabling the API is not enough, you
 * submit a request form and Google approves it. Until then every call comes
 * back 403 and this function is inert. See docs/google-reviews-sync.md.
 *
 * Secrets, set with `supabase secrets set`:
 *   GOOGLE_CLIENT_ID
 *   GOOGLE_CLIENT_SECRET
 *   GOOGLE_REFRESH_TOKEN   — from a one-time OAuth consent as the owner
 *   GOOGLE_LOCATION_NAME   — accounts/{accountId}/locations/{locationId}
 */

// Google returns the rating as a word, not a number.
const STAR: Record<string, number> = {
  ONE: 1,
  TWO: 2,
  THREE: 3,
  FOUR: 4,
  FIVE: 5,
};

interface GoogleReview {
  name: string;
  reviewer?: { displayName?: string; profilePhotoUrl?: string };
  starRating?: string;
  comment?: string;
  createTime?: string;
  updateTime?: string;
  reviewReply?: { comment?: string; updateTime?: string };
}

/** Exchanges the long-lived refresh token for an access token. */
async function getAccessToken(): Promise<string> {
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: Deno.env.get("GOOGLE_CLIENT_ID") ?? "",
      client_secret: Deno.env.get("GOOGLE_CLIENT_SECRET") ?? "",
      refresh_token: Deno.env.get("GOOGLE_REFRESH_TOKEN") ?? "",
      grant_type: "refresh_token",
    }),
  });

  const body = await res.json();
  if (!res.ok) {
    // invalid_grant means the token was revoked or expired — someone has to
    // re-consent. Worth saying plainly; it is the usual failure months later.
    throw new Error(
      `Google token refresh failed: ${res.status} ${JSON.stringify(body)}`,
    );
  }
  return body.access_token as string;
}

async function fetchAllReviews(
  token: string,
  location: string,
): Promise<GoogleReview[]> {
  const all: GoogleReview[] = [];
  let pageToken: string | undefined;

  do {
    const url = new URL(
      `https://mybusiness.googleapis.com/v4/${location}/reviews`,
    );
    url.searchParams.set("pageSize", "50");
    if (pageToken) url.searchParams.set("pageToken", pageToken);

    const res = await fetch(url, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const body = await res.json();

    if (!res.ok) {
      throw new Error(
        `Business Profile API ${res.status}: ${JSON.stringify(body).slice(0, 400)}`,
      );
    }

    all.push(...(body.reviews ?? []));
    pageToken = body.nextPageToken;
  } while (pageToken);

  return all;
}

Deno.serve(async (req) => {
  try {
    const location = Deno.env.get("GOOGLE_LOCATION_NAME");
    if (!location) {
      return Response.json(
        {
          error:
            "GOOGLE_LOCATION_NAME is not set. Expected accounts/{accountId}/locations/{locationId}.",
        },
        { status: 500 },
      );
    }

    const token = await getAccessToken();
    const reviews = await fetchAllReviews(token, location);

    const rows = reviews
      .map((r) => ({
        name: r.name,
        reviewer_name: r.reviewer?.displayName?.trim() || "Google user",
        reviewer_photo: r.reviewer?.profilePhotoUrl ?? null,
        rating: STAR[r.starRating ?? ""] ?? null,
        comment: r.comment?.trim() || null,
        reply: r.reviewReply?.comment?.trim() || null,
        reply_at: r.reviewReply?.updateTime ?? null,
        created_at: r.createTime,
        updated_at: r.updateTime ?? null,
        synced_at: new Date().toISOString(),
      }))
      // A review with no star rating cannot satisfy the check constraint, and
      // is no use on the site either.
      .filter((r) => r.rating !== null && r.created_at);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Upsert rather than replace: a reviewer can edit their text, and wiping
    // the table first would empty the homepage if the API failed midway.
    const { error } = await supabase
      .from("google_reviews")
      .upsert(rows, { onConflict: "name" });

    if (error) {
      throw new Error(`Upsert failed: ${error.message}`);
    }

    const withText = rows.filter((r) => r.comment).length;
    const avg = rows.length
      ? (rows.reduce((s, r) => s + (r.rating ?? 0), 0) / rows.length).toFixed(2)
      : null;

    return Response.json({
      synced: rows.length,
      withComment: withText,
      averageRating: avg,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("sync-google-reviews:", message);
    return Response.json({ error: message }, { status: 500 });
  }
});
