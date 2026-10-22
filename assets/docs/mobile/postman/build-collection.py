#!/usr/bin/env python3
"""Builds the mobile team's Postman collection from the API's OpenAPI description.

Usage: python3 build-collection.py [openapi.json]   (fetches https://api.travel.ams.com.kh/v3/api-docs when no file is given)
Writes "AMS Travel Mobile.postman_collection.json" and "AMS Travel.postman_environment.json" next to this script.
Folders follow the app's screens (see ../screens-to-api.md); every request reads {{baseUrl}} and sends {{token}}.
"""
import json, sys, urllib.request, os, uuid

HERE = os.path.dirname(os.path.abspath(__file__))
spec = json.load(open(sys.argv[1])) if len(sys.argv) > 1 else json.load(urllib.request.urlopen("https://api.travel.ams.com.kh/v3/api-docs"))
schemas = spec.get("components", {}).get("schemas", {})

# (folder, [(method, path, name, {query overrides}, body override or None)])
SCREENS = [
    ("0 · Sign in (Keycloak)", []),
    ("1 · Explore", [
        ("GET", "/api/v1/interests", "Interest chips (the six groups)", {}, None),
        ("GET", "/api/v1/regions", "Tourism region cards", {"kind": "TOURISM"}, None),
        ("GET", "/api/v1/popular", "Explore by Popular (ids)", {"limit": "10"}, None),
        ("GET", "/api/v1/search/cards", "Cards for ids (rows)", {"type": "DESTINATION", "ids": "{{destinationId}}"}, None),
        ("POST", "/api/v1/popular/events", "Record a browse", {}, {"destinationId": "{{destinationId}}", "eventType": "VIEW", "sessionId": "device-session-1"}),
        ("GET", "/api/v1/notifications", "Unread count for the bell", {"unreadOnly": "true", "limit": "1"}, None),
    ]),
    ("2 · Search", [
        ("GET", "/api/v1/search", "Search places", {"type": "DESTINATION", "q": "angkor", "page": "0", "size": "20"}, None),
        ("GET", "/api/v1/search", "Filter by regions, provinces, category, tag, interest (several ids comma-separated)", {"regionIds": "{{regionId}}", "provinceIds": "", "categoryIds": "", "tagIds": "", "interestIds": "", "size": "20"}, None),
        ("GET", "/api/v1/search", "Only the Traveler seal holders", {"travelerRecommended": "true", "size": "20"}, None),
        ("GET", "/api/v1/search/suggest", "Suggestions while typing", {"q": "ang", "limit": "8"}, None),
        ("GET", "/api/v1/search", "The same in Khmer: cards in Khmer where written, `untranslated` names the rest (also on by-province, suggest, cards)", {"type": "DESTINATION", "q": "អង្គរ", "lang": "km", "size": "20"}, None),
        ("GET", "/api/v1/search/suggest", "Suggestions in Khmer", {"q": "អង្គ", "limit": "8", "lang": "km"}, None),
        ("GET", "/api/v1/destinations/nearby", "Explore by Nearby", {"latitude": "13.4125", "longitude": "103.8670", "radiusKm": "25", "limit": "20"}, None),
        ("GET", "/api/v1/categories", "Category chips", {}, None),
        ("GET", "/api/v1/tags", "Tag chips", {}, None),
        ("GET", "/api/v1/provinces", "Province chips", {}, None),
    ]),
    ("3 · Tourism Regions", [
        ("GET", "/api/v1/regions/{id}", "A region: cover, overview, categories, tags", {}, None),
        ("GET", "/api/v1/search", "The region's places", {"regionId": "{{regionId}}", "size": "100"}, None),
    ]),
    ("4 · Destination detail", [
        ("GET", "/api/v1/destinations/{id}", "The place", {}, None),
        ("GET", "/api/v1/media", "Its gallery", {"ownerType": "DESTINATION", "ownerId": "{{destinationId}}"}, None),
        ("GET", "/api/v1/search/cards", "Rating, review count and seal in one call", {"ids": "{{destinationId}}"}, None),
        ("GET", "/api/v1/destination-verifications/status", "Verified standing", {"destinationId": "{{destinationId}}"}, None),
        ("GET", "/api/v1/reviews", "What travellers say (rating= narrows by stars)", {"targetType": "DESTINATION", "targetId": "{{destinationId}}", "page": "0", "size": "20", "rating": ""}, None),
        ("POST", "/api/v1/favorites", "Save (heart)", {}, {"targetType": "DESTINATION", "targetId": "{{destinationId}}"}),
        ("DELETE", "/api/v1/favorites/{targetType}/{targetId}", "Unsave", {}, None),
        ("POST", "/api/v1/media/files", "Upload a review photo (multipart, type=review)", {"type": "review"}, "multipart"),
        ("POST", "/api/v1/reviews", "Write a review", {}, {"targetType": "DESTINATION", "targetId": "{{destinationId}}", "rating": 5, "title": "Breathtaking sunrise", "content": "Arrive before five and walk the west causeway.", "visitType": "FAMILY", "visitedOn": "2026-08", "photoKeys": []}),
        ("PUT", "/api/v1/badges/me/explorations/{destinationId}", "Opened it (Browser badge + Popular)", {}, None),
        ("POST", "/api/v1/stamps", "Check in (scanned QR code + position, Adventure badge)", {}, {"code": "ABCD-EFGH-JKLM", "latitude": 13.4125, "longitude": 103.8670}),
    ]),
    ("5 · Popular page", [
        ("GET", "/api/v1/popular", "Popular with province and interest chips (filled up to limit; items[].reason)", {"type": "DESTINATION", "provinceIds": "", "interestIds": "", "limit": "50"}, None),
        ("GET", "/api/v1/popular", "Popular stays (type=STAY, FOOD or CORRIDOR)", {"type": "STAY", "limit": "10"}, None),
        ("POST", "/api/v1/popular/events", "Report a stay, food or corridor page opened", {}, {"targetType": "STAY", "targetId": "{{stayId}}", "eventType": "STAY_VIEW", "sessionId": "device-session"}),
    ]),
    ("6 · Stays, Food and Activities", [
        ("GET", "/api/v1/stays/{id}", "A stay", {}, None),
        ("GET", "/api/v1/search", "Stays near a destination, as cards nearest first", {"type": "STAY", "near": "{{destinationId}}"}, None),
        ("GET", "/api/v1/stays", "Stays near a destination (full details)", {"near": "{{destinationId}}"}, None),
        ("GET", "/api/v1/stay-rooms", "Its rooms", {"stayId": "{{stayId}}"}, None),
        ("GET", "/api/v1/stay-rooms/quote", "Price preview: one total for the nights", {"stayId": "{{stayId}}", "checkIn": "2026-10-16", "checkOut": "2026-10-18", "rooms": "1", "adults": "2", "children": "0"}, None),
        ("GET", "/api/v1/stay-rooms/{id}/quote", "Price preview for one room", {"checkIn": "2026-10-16", "checkOut": "2026-10-18", "rooms": "1", "adults": "2", "children": "0"}, None),
        ("GET", "/api/v1/amenities", "Amenity labels, icons and groups", {}, None),
        ("GET", "/api/v1/foods/{id}", "A food place", {}, None),
        ("GET", "/api/v1/search", "Food near a destination, as cards nearest first (openNow, todayHours)", {"type": "FOOD", "near": "{{destinationId}}"}, None),
        ("GET", "/api/v1/foods", "Food near a destination (full details)", {"near": "{{destinationId}}"}, None),
        ("GET", "/api/v1/search", "Activities & Experiences list (type=ACTIVITY; a chip is interestIds=)", {"type": "ACTIVITY", "size": "20"}, None),
        ("GET", "/api/v1/activities/{id}", "An activity (type, contact, Khmer)", {}, None),
        ("GET", "/api/v1/search", "Activities near a destination, as cards nearest first", {"type": "ACTIVITY", "near": "{{destinationId}}"}, None),
        ("GET", "/api/v1/media", "An activity's gallery", {"ownerType": "ACTIVITY", "ownerId": "{{activityId}}"}, None),
        ("GET", "/api/v1/search", "Recommend panel: the interest's Traveler seal holders", {"interestIds": "", "travelerRecommended": "true", "size": "5"}, None),
        ("GET", "/api/v1/media", "A stay's gallery", {"ownerType": "STAY", "ownerId": "{{stayId}}"}, None),
    ]),
    ("7 · Provinces", [
        ("GET", "/api/v1/provinces", "All 25 provinces (cover, centre, bounds, counts)", {}, None),
        ("GET", "/api/v1/search/by-province", "The Provinces page in one answer", {"type": "DESTINATION", "interestIds": "", "perProvince": "8"}, None),
        ("GET", "/api/v1/search", "Places in a province", {"provinceId": "{{provinceId}}", "size": "20"}, None),
        ("GET", "/api/v1/search", "Corridors through a province", {"type": "CORRIDOR", "provinceId": "{{provinceId}}"}, None),
        ("POST", "/api/v1/favorites", "Save a province (heart)", {}, {"targetType": "PROVINCE", "targetId": "{{provinceId}}"}),
    ]),
    ("8 · Map", [
        ("GET", "/api/v1/destinations/nearby", "Pins around the user", {"latitude": "11.5564", "longitude": "104.9282", "radiusKm": "10", "limit": "50"}, None),
        ("GET", "/api/v1/search", "Every corridor route at once (encodedPolyline per card)", {"type": "CORRIDOR", "size": "20"}, None),
        ("GET", "/api/v1/regions", "A marker per tourism region (latitude, longitude, bounds)", {"kind": "TOURISM"}, None),
        ("GET", "/api/v1/corridors/{id}/itinerary", "A corridor's stops and polylines", {}, None),
    ]),
    ("9 · Corridors", [
        ("GET", "/api/v1/search", "Corridor list", {"type": "CORRIDOR"}, None),
        ("GET", "/api/v1/corridors/{id}", "A corridor", {}, None),
        ("GET", "/api/v1/corridors/{id}/itinerary", "Route overview", {}, None),
        ("GET", "/api/v1/media", "Its gallery", {"ownerType": "CORRIDOR", "ownerId": "{{corridorId}}"}, None),
        ("GET", "/api/v1/reviews", "Its reviews", {"targetType": "CORRIDOR", "targetId": "{{corridorId}}"}, None),
        ("POST", "/api/v1/favorites", "Save a corridor", {}, {"targetType": "CORRIDOR", "targetId": "{{corridorId}}"}),
    ]),
    ("10 · Saves", [
        ("GET", "/api/v1/favorites", "Everything saved (type + id)", {}, None),
        ("GET", "/api/v1/search/cards", "Rows for the saved ids", {"type": "DESTINATION", "ids": "{{destinationId}}"}, None),
    ]),
    ("11 · Notifications", [
        ("GET", "/api/v1/notifications", "List", {"unreadOnly": "false", "limit": "50"}, None),
        ("PUT", "/api/v1/notifications/{id}/read", "Mark one read", {}, None),
        ("PUT", "/api/v1/notifications/read-all", "Mark all read", {}, None),
        ("DELETE", "/api/v1/notifications/{id}", "Delete one", {}, None),
    ]),
    ("12 · Profile and Account", [
        ("GET", "/api/v1/users/me", "Me", {}, None),
        ("PUT", "/api/v1/users/me", "Edit profile (the whole profile each time)", {}, {"fullName": "Dara Sok", "phone": "+855 12 345 678", "avatarKey": "", "homeProvinceId": "{{provinceId}}"}),
        ("POST", "/api/v1/media/files", "Upload a profile photo (multipart, type=avatar)", {"type": "avatar"}, "multipart"),
        ("GET", "/api/v1/reviews/me", "My reviews (rating= narrows by stars)", {"page": "0", "size": "20", "rating": ""}, None),
        ("GET", "/api/v1/stamps/me", "My check-ins", {}, None),
        ("GET", "/api/v1/points/me", "My points", {}, None),
    ]),
    ("13 · Badges", [
        ("GET", "/api/v1/badges", "Badge definitions", {}, None),
        ("GET", "/api/v1/badges/me/progress", "My progress this season", {}, None),
        ("GET", "/api/v1/badges/me/earned", "My earned badges", {}, None),
        ("GET", "/api/v1/badges/shared/{userBadgeId}", "A shared badge (public page)", {}, None),
        ("GET", "/api/v1/seasons/current", "The current season", {}, None),
        ("GET", "/api/v1/seasons/me/history", "My seasons", {}, None),
    ]),
    ("14 · Reviews (mine)", [
        ("GET", "/api/v1/reviews/{id}", "One review", {}, None),
        ("PUT", "/api/v1/reviews/{id}", "Edit", {}, {"rating": 4, "title": "Still breathtaking", "content": "Second visit, just as good.", "visitType": "COUPLES", "visitedOn": "2026-09"}),
        ("DELETE", "/api/v1/reviews/{id}", "Delete", {}, None),
    ]),
    ("15 · Preferences", [
        ("GET", "/api/v1/preferences/me", "My preferences", {}, None),
        ("PUT", "/api/v1/preferences/me", "Save preferences", {}, {"preferredLanguage": "en", "preferredCurrency": "USD", "preferredRegionId": None, "notificationEmail": True, "notificationPush": True, "theme": "SYSTEM", "distanceUnit": "KM"}),
    ]),
]

PUBLIC_GET_PREFIXES = ("/api/v1/search", "/api/v1/destinations", "/api/v1/stays", "/api/v1/stay-rooms", "/api/v1/foods", "/api/v1/activities", "/api/v1/corridors",
                       "/api/v1/regions", "/api/v1/provinces", "/api/v1/categories", "/api/v1/tags", "/api/v1/interests", "/api/v1/amenities",
                       "/api/v1/media", "/api/v1/popular", "/api/v1/reviews", "/api/v1/ratings", "/api/v1/destination-verifications/status",
                       "/api/v1/badges", "/api/v1/seasons")
# Writes the API accepts without a token (a browse can be reported by a guest).
PUBLIC_WRITES = {("POST", "/api/v1/popular/events")}

def example_for(schema, depth=0):
    """A plausible body from a component schema: one value per first-level property."""
    if "$ref" in schema:
        schema = schemas.get(schema["$ref"].split("/")[-1], {})
    kind = schema.get("type")
    if kind == "object" or "properties" in schema:
        return {name: example_for(prop, depth + 1) for name, prop in schema.get("properties", {}).items()} if depth < 2 else {}
    if kind == "array":
        return [] if depth > 1 else [example_for(schema.get("items", {}), depth + 1)]
    if "enum" in schema:
        return schema["enum"][0]
    fmt = schema.get("format", "")
    return {"integer": 1, "number": 1.0, "boolean": True}.get(kind, "2026-10-16" if fmt == "date" else "uuid" if fmt == "uuid" else "text")

def operation(method, path):
    item = spec["paths"].get(path, {}).get(method.lower())
    return item or {}

def request(method, path, name, query, body):
    op = operation(method, path)
    # {{baseUrl}} already ends in /api/v1, so the request path starts after it.
    url_path = path.removeprefix("/api/v1").replace("{id}", "{{id}}").replace("{targetType}", "DESTINATION").replace("{targetId}", "{{destinationId}}") \
        .replace("{destinationId}", "{{destinationId}}").replace("{userBadgeId}", "{{userBadgeId}}")
    params = []
    declared = {p["name"]: p for p in op.get("parameters", []) if p.get("in") == "query"}
    for key, value in query.items():
        params.append({"key": key, "value": str(value), "disabled": value == "", "description": declared.get(key, {}).get("description", "")})
    for key, p in declared.items():
        if key not in query and key not in ("page", "size", "sort"):
            params.append({"key": key, "value": "", "disabled": True, "description": p.get("description", "")})
    # Judged on the full path, before /api/v1 is stripped: the prefixes carry it.
    mine = path.endswith("/me") or "/me/" in path   # the traveller's own things ("/media" is not that)
    public = (method == "GET" and path.startswith(PUBLIC_GET_PREFIXES) and not mine) \
        or (method, path) in PUBLIC_WRITES
    req = {
        "name": name,
        "request": {
            "method": method,
            "header": [],
            "url": {"raw": "{{baseUrl}}" + url_path + ("?" + "&".join(f"{p['key']}={p['value']}" for p in params if not p["disabled"]) if any(not p["disabled"] for p in params) else ""),
                    "host": ["{{baseUrl}}"], "path": [s for s in url_path.strip("/").split("/")], "query": params},
            "description": (op.get("summary") or op.get("description") or "") + ("\n\nPublic: no token needed." if public else "\n\nNeeds the traveller's token."),
        },
        "response": [],
    }
    if public:
        req["request"]["auth"] = {"type": "noauth"}
    if body == "multipart":
        req["request"]["body"] = {"mode": "formdata", "formdata": [{"key": "file", "type": "file", "src": ""}]}
    elif body is not None:
        req["request"]["header"].append({"key": "Content-Type", "value": "application/json"})
        req["request"]["body"] = {"mode": "raw", "raw": json.dumps(body, indent=2), "options": {"raw": {"language": "json"}}}
    elif method in ("POST", "PUT") and "requestBody" in op:
        schema = op["requestBody"]["content"].get("application/json", {}).get("schema", {})
        req["request"]["header"].append({"key": "Content-Type", "value": "application/json"})
        req["request"]["body"] = {"mode": "raw", "raw": json.dumps(example_for(schema), indent=2), "options": {"raw": {"language": "json"}}}
    return req

token_request = {
    "name": "Get a traveller token (password grant, testing shortcut)",
    "event": [{"listen": "test", "script": {"type": "text/javascript", "exec": [
        "const body = pm.response.json();",
        "if (body.access_token) { pm.environment.set('token', body.access_token); pm.test('token stored in the environment', () => true); }",
        "else { pm.test('no token: ' + JSON.stringify(body), () => false); }"]}}],
    "request": {
        "method": "POST", "auth": {"type": "noauth"},
        "header": [{"key": "Content-Type", "value": "application/x-www-form-urlencoded"}],
        "url": {"raw": "{{keycloakUrl}}/realms/amstravel/protocol/openid-connect/token", "host": ["{{keycloakUrl}}"], "path": ["realms", "amstravel", "protocol", "openid-connect", "token"]},
        "body": {"mode": "urlencoded", "urlencoded": [
            {"key": "grant_type", "value": "password"}, {"key": "client_id", "value": "local-cli"},
            {"key": "username", "value": "{{username}}"}, {"key": "password", "value": "{{password}}"}]},
        "description": "Testing shortcut only: the app itself signs in through Keycloak's pages with the public client amstravel-mobile (PKCE). Fill username and password in the environment; the test script stores the token for every other request.",
    },
    "response": [],
}

collection = {
    "info": {"_postman_id": str(uuid.uuid4()), "name": "AMS Travel Mobile",
             "description": "The AMS Travel API as the mobile app uses it, one folder per screen. Built by docs/mobile/postman/build-collection.py from the API's OpenAPI description on 2026-10-14. Reads marked public need no token; the rest send the traveller's bearer token from {{token}}. See docs/mobile/screens-to-api.md for what each screen needs.",
             "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"},
    "auth": {"type": "bearer", "bearer": [{"key": "token", "value": "{{token}}", "type": "string"}]},
    "variable": [{"key": "baseUrl", "value": "https://api.travel.ams.com.kh/api/v1"}],
    "item": [],
}
for folder, requests in SCREENS:
    items = [token_request] if folder.startswith("0") else [request(*r) for r in requests]
    collection["item"].append({"name": folder, "item": items})

environment = {
    "id": str(uuid.uuid4()), "name": "AMS Travel",
    "values": [
        {"key": "baseUrl", "value": "https://api.travel.ams.com.kh/api/v1", "enabled": True},
        {"key": "keycloakUrl", "value": "https://auth.travel.ams.com.kh", "enabled": True},
        {"key": "username", "value": "visitor@ams.test", "enabled": True},
        {"key": "password", "value": "", "enabled": True, "type": "secret"},
        {"key": "token", "value": "", "enabled": True, "type": "secret"},
        {"key": "destinationId", "value": "", "enabled": True},
        {"key": "regionId", "value": "", "enabled": True},
        {"key": "provinceId", "value": "", "enabled": True},
        {"key": "stayId", "value": "", "enabled": True},
        {"key": "activityId", "value": "", "enabled": True},
        {"key": "corridorId", "value": "", "enabled": True},
        {"key": "id", "value": "", "enabled": True},
        {"key": "userBadgeId", "value": "", "enabled": True},
    ],
    "_postman_variable_scope": "environment",
}
json.dump(collection, open(os.path.join(HERE, "AMS Travel Mobile.postman_collection.json"), "w"), indent=2, ensure_ascii=False)
json.dump(environment, open(os.path.join(HERE, "AMS Travel.postman_environment.json"), "w"), indent=2, ensure_ascii=False)
total = sum(len(f["item"]) for f in collection["item"])
missing = [(m, p) for _, reqs in SCREENS for (m, p, *_rest) in reqs if not operation(m, p)]
print(f"{len(collection['item'])} folders, {total} requests; not in the OpenAPI description: {missing}")
