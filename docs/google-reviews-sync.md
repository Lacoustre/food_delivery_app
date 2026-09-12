# Syncing Google reviews

The homepage carousel reads `google_reviews`, filled by the
`sync-google-reviews` edge function. While that table is empty it falls back to
a hardcoded list, so nothing breaks before this is switched on.

**Everything below is blocked on Google approving API access by hand.** The
code is written and deployed; it returns 403 until then.

## 1. Request access (do this first — it is the long pole)

1. Create or pick a Google Cloud project on the same account that owns the
   Business Profile.
2. Enable **Google My Business API**, **My Business Account Management API**
   and **My Business Business Information API**.
3. Submit the access request form:
   https://developers.google.com/my-business/content/prereqs
   Google reviews it manually — days, sometimes weeks, and they can decline.
   Approval is per Google Cloud project, not per person.

Reviews still live on the old v4 endpoint. Google split the rest of the
Business Profile APIs into newer services but never moved reviews, which is
why the function calls `mybusiness.googleapis.com/v4`.

## 2. OAuth, once approved

1. **APIs & Services > Credentials > Create OAuth client ID > Web application**.
2. Add `https://developers.google.com/oauthplayground` as a redirect URI.
3. Open the OAuth Playground, click the gear, tick **Use your own OAuth
   credentials**, paste the client id and secret.
4. Authorise the scope `https://www.googleapis.com/auth/business.manage`,
   signing in as the account that owns the Business Profile.
5. Exchange the code for tokens and keep the **refresh token**.

The refresh token is long-lived but not permanent: revoking access, changing
the account password, or six months of disuse will kill it. When reviews stop
updating, this is the first thing to check — the function reports
`invalid_grant` in that case.

## 3. Find the location name

With an access token:

    curl -H "Authorization: Bearer $TOKEN" \
      https://mybusinessaccountmanagement.googleapis.com/v1/accounts

    curl -H "Authorization: Bearer $TOKEN" \
      "https://mybusinessbusinessinformation.googleapis.com/v1/accounts/{accountId}/locations?readMask=name,title"

`GOOGLE_LOCATION_NAME` is `accounts/{accountId}/locations/{locationId}`.

## 4. Secrets and deploy

    supabase secrets set \
      GOOGLE_CLIENT_ID=... \
      GOOGLE_CLIENT_SECRET=... \
      GOOGLE_REFRESH_TOKEN=... \
      GOOGLE_LOCATION_NAME=accounts/123/locations/456

    supabase functions deploy sync-google-reviews

Run it once by hand and check the response reports a sensible count.

## 5. Schedule it

Reviews change slowly; hourly is plenty and daily is defensible.

    select cron.schedule(
      'sync-google-reviews',
      '0 * * * *',
      $$ select net.http_post(
           url := 'https://peimbksjyjcxmurwwmnn.supabase.co/functions/v1/sync-google-reviews',
           headers := '{"Authorization": "Bearer <service-role-key>"}'::jsonb
         ) $$
    );

pg_cron and pg_net are already enabled (migrations 11 and 12).

## Notes

- Only reviews **with text** reach the carousel. A bare five stars with no
  words makes a poor slide.
- The sync **upserts**; it never clears the table first. A failure halfway
  leaves the last good set in place rather than emptying the homepage.
- Google's rating is a word (`FIVE`), mapped to an integer on the way in.
- Once real reviews appear, delete the hardcoded `fallbackReviews` from
  page.tsx. Two of those six could not be verified against the Business
  Profile and should not outlive the switch-over.
