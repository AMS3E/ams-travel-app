# Prompt for Claude Code

Put this folder inside the app's repo as `api-docs/`, open Claude Code from the app's repo, and paste
everything below the line as the first message.

---

I am building the AMS Travel mobile app against the AMS Travel API, which runs on the company server:
API base URL `https://api.travel.ams.com.kh/api/v1`, sign-in through Keycloak at
`https://auth.travel.ams.com.kh/realms/amstravel`. The backend team's documentation is in this repo under
`api-docs/`; nothing from the backend runs on my machine.

Before you write any code, read these files in `api-docs/` and keep them as the source of truth:
1. `README.md`: the addresses, how sign-in works (Keycloak, authorization code with PKCE, client
   `amstravel-mobile`, redirect `amstravel://callback`), registration with the email code, and the
   conventions of the API (paging, picture links, errors).
2. `screens-to-api.md`: every screen of the app and the exact endpoint, parameters and fields behind each
   element. Follow it; do not invent endpoints or fields.
3. `postman/AMS Travel Mobile.postman_collection.json`: a request example for every call.
4. `API-REQUESTS.md`: the report for anything the API lacks. Copy it to the root of this repo the first
   time you need it.

Rules for this integration:
- Guest mode first: every read is public and needs no token. Signed-in calls send the bearer token.
- Sign-in, sign-up, the email code and forgot-password are Keycloak's pages opened through AppAuth with the
  values in `README.md`. Build no form for them and call no endpoint for them.
- Lists are made of the "card" that `GET /search` and `GET /search/cards` return; a row never needs a
  second call. Paged answers are `{content, page}`.
- Never filter the catalogue on the phone: search, filters and suggestions are server calls.
- Picture links are paths; prefix them with the server origin `https://api.travel.ams.com.kh`.
- Stays show one total for the chosen nights from `GET /stay-rooms/quote`, never a per-night price.
- A review is one `POST /reviews` with rating, title, content, visitType, visitedOn and photo keys; photos
  are uploaded first with `POST /media/files` (type `review`).
- The Menu screen of the design is out of scope.
- When a screen needs something the API does not give (a missing field, a value in the wrong shape, a
  filter a list lacks, an action with no endpoint, one answer where it takes three calls), never work around
  it on the phone. Append an entry to `API-REQUESTS.md` at the root of this repo, in the shape that file
  shows, leave the element as a `TODO R-nnn` that degrades gracefully, and carry on with the next screen.
  Kimleng takes that file to the backend.

Start by checking the API answers (`GET https://api.travel.ams.com.kh/api/v1/search?q=angkor`). Then, in
this order: the API client with the conventions above; the Explore screen as a guest from the public reads
(interest chips, tourism region cards, popular rows); sign-in and sign-up through Keycloak with AppAuth, and
the profile read after it; then the remaining screens in the order of `screens-to-api.md`. Show me each
screen working against the server before moving to the next.
