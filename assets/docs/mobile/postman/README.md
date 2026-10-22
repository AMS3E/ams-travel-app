# The collection for Insomnia or Postman

Import both files (Insomnia: Application → Preferences → Data → Import; Postman: File → Import):

- `AMS Travel Mobile.postman_collection.json`: the API as the app uses it, one folder per screen, 70 requests. Every request reads `{{baseUrl}}`; the ones that need a signed-in traveller send `{{token}}` as a bearer token, the public reads send nothing.
- `AMS Travel.postman_environment.json`: `baseUrl` and `keycloakUrl` pointed at the company server, the test traveller's `username` (`visitor@ams.test`; ask Kimleng for the `password`, or put an account you registered yourself), and empty ids to fill in as you go (`destinationId`, `regionId`, `provinceId`, `stayId`, `corridorId`, `id`, `userBadgeId`).

Select the environment "AMS Travel", then start with folder **0 · Sign in**: "Get a traveller token" stores the token in the environment for everything else. That request is a testing shortcut (password grant on the `local-cli` client); the app itself signs in through Keycloak's pages, see `../README.md`.

Then **2 · Search** → "Search places" gives ids to paste into the environment, and the other folders follow the screens in `../screens-to-api.md`.

To rebuild after an API change (the server describes itself at `/v3/api-docs`):

```bash
python3 build-collection.py                 # from the server
python3 build-collection.py openapi.json    # from the saved description
```
