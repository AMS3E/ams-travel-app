# AMS Travel API: mobile integration

The backend the app talks to runs on the company server. There is nothing to install and nothing to run
on your machine. Read this file first, then `screens-to-api.md` for what each screen calls, and import
`postman/` into Insomnia or Postman to try every call before you write it.

## 1. Addresses

| Piece | Address |
| --- | --- |
| API base URL | https://api.travel.ams.com.kh/api/v1 |
| API reference (Swagger UI) | https://api.travel.ams.com.kh/swagger-ui/index.html |
| Sign-in (Keycloak issuer) | https://auth.travel.ams.com.kh/realms/amstravel |
| CMS, staff only | https://cms.travel.ams.com.kh |

The same server is where new versions of the API are deployed. It is unavailable for a few minutes during
a deploy, and Kimleng tells you before pressing the button. Its content is the seeded catalogue plus what the
staff add in the CMS. Whatever your testing creates (accounts, favourites, reviews, check-ins) stays there
until launch, when the traveller data is wiped.

## 2. Guest and signed-in

A guest needs no token: every read the app makes is public (search, places, stays, food, activities, corridors,
regions, provinces, interests, popular, nearby, the price quote, galleries). Browses can be reported
without signing in too.

A signed-in traveller sends `Authorization: Bearer <access token>` on every request. The first request
with a new token creates the traveller's row in the API by itself; nothing to register on the API side.

## 3. Signing in from the app

The app signs in through Keycloak's own pages with the standard **authorization code + PKCE** flow,
using the system browser. Use AppAuth (`react-native-app-auth`, `flutter_appauth`, AppAuth-iOS,
AppAuth-Android) with these values:

| Setting | Value |
| --- | --- |
| Issuer / discovery | `https://auth.travel.ams.com.kh/realms/amstravel` (its `.well-known/openid-configuration` is served) |
| Client id | `amstravel-mobile` |
| Redirect URI | `amstravel://callback` (register the `amstravel` URL scheme in the app) |
| Scopes | `openid profile email offline_access` |
| PKCE | S256, required |

Keycloak's pages handle sign-in, **registration**, forgot-password, and the **six-digit email code**
after registration (the app's Verify OTP screen). The code is emailed to the address the traveller typed,
so register with an inbox you can read; Gmail's `name+anything@gmail.com` aliases give you as many test
accounts as you need from one inbox. The pages carry the AMS Travel look. To open registration directly,
send the user to the issuer's `/protocol/openid-connect/registrations` endpoint with the same parameters
as the authorize call.

Refresh tokens come back with the token; refresh at `<issuer>/protocol/openid-connect/token`
(`grant_type=refresh_token`). Sign out with the `end_session_endpoint` from the discovery document.
An expired or missing token gets a `401`; a token without the right to do something gets a `403`.

## 4. Test accounts

Register your own traveller through the app's flow: that is the real path, and it exercises the email
code. A ready traveller exists too, `visitor@ams.test`; ask Kimleng for its password. The staff accounts
(`admin@ams.test` and others) belong to the back-office realm `amsadmin` and are not for the app.

## 5. Conventions of the API

- **Paging**: list answers are `{"content": [...], "page": {"size", "number", "totalElements", "totalPages"}}`;
  ask for a page with `page` (from 0) and `size`.
- **Pictures**: every picture link is a path such as `/api/v1/media/files/general/.../photo.jpg`. Put the
  server origin `https://api.travel.ams.com.kh` in front of it (the origin, not the base URL).
- **Errors**: a problem JSON `{"title", "status", "detail", "instance"}`; `detail` is the sentence to show
  or log.
- **Ids** are UUIDs, **dates** are ISO (`2026-10-14`, months `2026-10`), **money** is `priceFrom` plus
  `currency`.
- **Several ids** go comma-separated (`provinceIds=a,b`, `regionIds=`, `interestIds=`); `provinceId=` and
  `regionId=` still take one. **Hours** are `{"mon": "07:00-22:00", …}`, `closed` or no key for a shut day,
  and every food answer carries `openNow` and `todayHours` computed in Cambodia time.
- **Lists are made of one card**: `GET /search` and `GET /search/cards` return the same card for a place,
  a stay, a food place or a corridor; a row never needs a second call (see `screens-to-api.md`).

## 6. Trying calls without the app

Import `postman/` into Insomnia or Postman (see its README) and pick the environment "AMS Travel". Its
"Get a traveller token" request is a testing shortcut (password grant on the `local-cli` client) so you can
try signed-in calls without the app's sign-in screen; the app itself always goes through Keycloak's pages.

## 7. When the API does not fit a screen

The app follows the Figma screens, the API follows its data model, and they will disagree in places. Do not
patch around a gap on the phone: write it into `API-REQUESTS.md` (copy the template from this folder into
the root of the app repo), one entry per need in the shape it shows, and send that file to Kimleng. The
backend answers each entry in its Status line, and the file comes back. Claude Code is told the same in
`CLAUDE-PROMPT.md`.

## 8. Working with Claude Code

Put this folder inside your app's repo as `api-docs/`, open Claude Code from the app's repo, and paste the
prompt in `CLAUDE-PROMPT.md` as your first message. Nothing from the backend runs on your machine.
After the backend answers `API-REQUESTS.md`, replace `api-docs/` with the new folder and paste
`CLAUDE-PROMPT-2.md` (2026-10-14) as the next message: it tells Claude Code how to carry the answers into the app.
