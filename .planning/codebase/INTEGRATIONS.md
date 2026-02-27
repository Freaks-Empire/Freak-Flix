# External Integrations

**Analysis Date:** 2026-02-27

## APIs & External Services

**Metadata APIs:**
- TMDB (The Movie Database) - movie/TV search and enrichment in `lib/services/tmdb_service.dart`
  - SDK/Client: `http` (`package:http/http.dart`)
  - Auth: `TMDB_API_KEY` (loaded via `lib/providers/settings_provider.dart` and `lib/services/secure_key_service.dart`)
- AniList GraphQL - anime metadata and details in `lib/services/anilist_service.dart`
  - SDK/Client: `http`
  - Auth: None detected (public GraphQL endpoint usage)
- Trakt API - optional metadata enrichment in `lib/services/trakt_service.dart`
  - SDK/Client: `http`
  - Auth: `TRAKT_CLIENT_ID` (`String.fromEnvironment` in `lib/services/trakt_service.dart`)
- StashDB / StashBox GraphQL endpoints - adult metadata lookup in `lib/services/stash_db_service.dart`
  - SDK/Client: `http`
  - Auth: per-endpoint API key stored in app settings (`lib/models/stash_endpoint.dart`, `lib/providers/settings_provider.dart`)

**Cloud Storage APIs:**
- Microsoft Graph (OneDrive) - account auth, folder traversal, file streaming/upload/backup in `lib/services/graph_auth_service.dart`, `lib/services/onedrive_scan_service.dart`, `lib/screens/onedrive_browser_screen.dart`
  - SDK/Client: `http`
  - Auth: `GRAPH_CLIENT_ID`, `GRAPH_TENANT_ID` (or `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`) in `lib/services/graph_auth_service.dart`

**Remote Protocol Integrations:**
- SFTP - remote file browsing/stream preparation in `lib/services/sftp_client.dart`
  - SDK/Client: `dartssh2`
  - Auth: username/password (and optional key storage via `lib/services/remote_storage_service.dart`)
- FTP - remote file browsing in `lib/services/ftp_client_wrapper.dart`
  - SDK/Client: `ftpconnect`
  - Auth: username/password stored via `lib/services/remote_storage_service.dart`
- WebDAV - remote file browsing/streaming in `lib/services/webdav_client_wrapper.dart`
  - SDK/Client: `webdav_client`
  - Auth: username/password stored via `lib/services/remote_storage_service.dart`

**Playback/Embed Service:**
- Vidking embed service - remote embed URL generation in `lib/services/vidking_service.dart`
  - SDK/Client: URL generation only
  - Auth: None detected

## Data Storage

**Databases:**
- Local app state only (no server-side DB detected)
  - Connection: Not applicable
  - Client: `shared_preferences` and file-based persistence (`lib/services/persistence_service.dart`)

**File Storage:**
- Local filesystem for app data via application support directory in `lib/services/persistence_service.dart`
- OneDrive cloud storage for backup/sync/media paths via Microsoft Graph in `lib/services/graph_auth_service.dart`

**Caching:**
- In-memory service caches for API responses in `lib/services/tmdb_discover_service.dart`, `lib/services/anilist_service.dart`, `lib/services/trakt_service.dart`, `lib/services/stash_db_service.dart`
- Persistent cache/state in `SharedPreferences` and JSON files through `lib/services/persistence_service.dart`

## Authentication & Identity

**Auth Provider:**
- Microsoft Entra ID / Microsoft Account OAuth for Graph access in `lib/services/graph_auth_service.dart`
  - Implementation: device-code flow on non-web (`requestDeviceCode`/`pollDeviceCode`) and popup OAuth+PKCE on web (`lib/services/graph_auth_web.dart`)
- Netlify function mediates web code-to-token exchange in `netlify/functions/oauth-token.js`

## Monitoring & Observability

**Error Tracking:**
- New Relic mobile SDK integrated but mobile init block is currently commented/disabled in `lib/services/monitoring/monitoring_mobile.dart`
- Web monitoring is a no-op stub in `lib/services/monitoring/monitoring_web.dart`

**Logs:**
- App logging uses `debugPrint` and custom logger wrappers in `lib/utils/logger.dart` and `lib/utils/secure_logger.dart`

## CI/CD & Deployment

**Hosting:**
- Web deployment via Netlify (`netlify.toml`, `netlify/build.sh`)
- Desktop/mobile artifacts published to GitHub Releases (`.github/workflows/build-windows.yml`, `.github/workflows/flutter-android.yml`)

**CI Pipeline:**
- GitHub Actions workflows for Windows and Android build/release automation in `.github/workflows/*.yml`

## Environment Configuration

**Required env vars:**
- `TMDB_API_KEY` for TMDB metadata (`lib/providers/settings_provider.dart`)
- `GRAPH_CLIENT_ID`, `GRAPH_TENANT_ID` for Microsoft Graph auth (`lib/services/graph_auth_service.dart`)
- `TRAKT_CLIENT_ID` for Trakt metadata (`lib/services/trakt_service.dart`)
- Optional aliases: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` (`lib/services/graph_auth_service.dart`)

**Secrets location:**
- Local development: root `.env` file loaded by `lib/main.dart` (file exists; contents not analyzed)
- CI: GitHub Actions secrets referenced in `.github/workflows/flutter-windows.yml`, `.github/workflows/build-windows.yml`, `.github/workflows/flutter-android.yml`
- Web deploy: Netlify environment variables consumed in `netlify/build.sh`

## Webhooks & Callbacks

**Incoming:**
- OAuth browser callback page at `web/auth-callback.html` for Microsoft login popup flow (`lib/services/graph_auth_web.dart`)
- Netlify function endpoint `/.netlify/functions/oauth-token` implemented in `netlify/functions/oauth-token.js`

**Outgoing:**
- App calls external APIs: TMDB (`lib/services/tmdb_service.dart`), AniList (`lib/services/anilist_service.dart`), Trakt (`lib/services/trakt_service.dart`), StashDB (`lib/services/stash_db_service.dart`), Microsoft Graph (`lib/services/graph_auth_service.dart`)
- Netlify function calls Microsoft token endpoint `https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token` in `netlify/functions/oauth-token.js`

---

*Integration audit: 2026-02-27*
