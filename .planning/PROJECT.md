# Freak-Flix

## What This Is

Freak-Flix is a cross-platform, Netflix-style personal media library manager and premium player for local and cloud video collections. It is built for privacy-conscious users who want rich metadata, fast browsing, and reliable playback without running a dedicated media server. It supports Movies, TV, Anime, and an opt-in Adult library with source-specific metadata providers.

## Core Value

Users can connect their own local or cloud storage and immediately get a polished, metadata-rich, serverless streaming-library experience with reliable cross-platform playback.

## Requirements

### Validated

- ✓ Cross-platform Flutter app foundation for Windows, Android, and Web exists in repository — existing
- ✓ Core media library + playback architecture with Provider/GoRouter/Media Kit is already established — existing
- ✓ Multi-backend direction (Local, OneDrive, SFTP, FTP, WebDAV) and security-testing culture are already established — existing

### Active

- [ ] Stabilize and harden vNext baseline for onboarding, scanning, metadata matching, and playback reliability
- [ ] Ensure OneDrive Device Code Flow and multi-storage UX are consistent across platforms
- [ ] Deliver robust metadata + cache + offline browsing behavior for Movies/TV/Anime and optional Adult content
- [ ] Improve performance and reliability for large libraries and unreliable remote networks
- [ ] Strengthen sync/backup behavior for cross-device playback state

### Out of Scope

- Pirated content workflows, torrenting features, or scraping streaming sites — violates product purpose and legal/safety boundaries
- Full multi-user always-on server architecture as primary mode — product is serverless-first personal library software
- Heavy transcoding pipeline as baseline — high complexity and not required for current core value
- DRM playback for commercial streaming platforms — outside technical/legal scope for this product

## Context

- Existing codebase is Flutter-based with established architecture and platform targets.
- Product scope spans mixed content libraries (Movies, TV, Anime, optional Adult) with provider-specific metadata integrations.
- Key backend/storage directions include local files and cloud/remote protocols (OneDrive, SFTP, FTP, WebDAV).
- Security posture is a hard project constraint: command injection, directory traversal, and SSRF protections must remain enforced by tests.
- Vision emphasizes privacy and user control: no vendor content hosting, transparent metadata fetch behavior, and offline-capable browsing after initial ingestion.

## Constraints

- **Architecture**: Serverless-first client application — users must not be required to host a dedicated server.
- **Platforms**: Windows, Android, and Web parity for core flows — baseline user journeys must function on all targets.
- **Security**: Input validation and security test suite must remain mandatory — regressions are unacceptable.
- **Metadata Providers**: TMDB, AniList, and optional StashDB contracts/rate limits must be respected.
- **Offline**: Browsing and local metadata/image cache must remain usable offline after setup.
- **Privacy/Compliance**: Adult library is opt-in and hidden by default; no content distribution behavior.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Keep serverless-first architecture as core product shape | Primary user value is privacy and direct storage ownership without running a server | — Pending |
| Use Device Code Flow as OneDrive auth baseline | Works consistently across Windows/Android/Web and avoids brittle popup auth flows | — Pending |
| Keep Adult library optional and hidden by default | Supports opt-in use case while preserving privacy-first default UX and safer baseline behavior | — Pending |
| Prioritize reliability/security/performance hardening before major delight features | vNext quality and trust determine adoption more than adding surface-area features early | — Pending |

---
*Last updated: 2026-02-27 after initialization*
