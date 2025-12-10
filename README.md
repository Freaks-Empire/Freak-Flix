# Freak-Flix
Netsflix But Open Source

## Freak-Flix (Flutter) Setup
- flutter pub get
- flutter run -d linux|macos|windows|android
- Configure Trakt Client ID in `lib/services/trakt_service.dart` (`_traktClientId`)
- AniList uses the public endpoint; adjust the query in `lib/services/anilist_service.dart`
- Add new metadata providers via `lib/services/metadata_service.dart`
- MPV playback via `flutter_mpv`: on Windows place `mpv-1.dll` next to the built exe; on Linux install `libmpv-dev` (e.g., `sudo apt install libmpv-dev`).

## Deploying to Netlify (web)
- Build: `flutter build web --release`
- Deploy directory: `build/web` (configured in `netlify.toml`)
- SPA routing: handled via the redirect in `netlify.toml` (all routes → `/index.html`).
- Set your API keys (TMDB, Graph/Azure, etc.) as Netlify environment variables; avoid hard-coding in the build.

### Netlify DB (Neon) for user accounts
- Requires Netlify’s Neon/DB extension to be enabled on the site.
- Netlify injects `NETLIFY_DB_CONNECTION` / `NETLIFY_DB_CONNECTION_STRING` into Functions.
- A sample function is in `netlify/functions/users.js` (register/login with email+password, bcrypt, Postgres table `app_users`, JWT issuance).
- Install function deps locally before deploying: `npm --prefix netlify/functions install`.
- Env var required: `JWT_SECRET` (set in Netlify site settings; optional `JWT_EXPIRY`, default `7d`).
- Deploy as usual; call `POST /.netlify/functions/users` with JSON `{ action: "register"|"login", email, password }` to receive `{ user, token }`. Use `action: "me"` with `Authorization: Bearer <token>` to validate.
