# Feature Research

**Domain:** personal media library manager/player (serverless-first, multi-storage)
**Researched:** 2026-02-27
**Confidence:** MEDIUM

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Multi-source library ingest (local, OneDrive, SFTP, FTP, WebDAV) | Core promise is "my files from anywhere" | HIGH | Requires unified adapter interface, credential handling, path normalization, and resilient scan jobs per backend. |
| Metadata enrichment (movies/TV/anime) | Users expect poster art, episode data, cast, and genres | MEDIUM | Build provider abstraction for TMDB/AniList/StashDB with source priority and manual override workflow. |
| Reliable playback with resume/progress | A media app without seamless play/resume is a deal-breaker | MEDIUM | Requires consistent media IDs, heartbeat progress writes, and recovery after abrupt app close. |
| Library browsing and search (title, genre, status) | Users need fast navigation once library grows | MEDIUM | Needs indexed local cache and normalized metadata schema across movie/TV/anime types. |
| Offline browsing of previously indexed library | Multi-device and travel users expect browsing without network | MEDIUM | Persist metadata/artwork cache locally; mark offline-safe features vs online-required actions. |
| Sync state across devices (watch progress, watchlist, settings profile) | Multi-device behavior is now baseline | HIGH | Use user-owned cloud sync document model (not hosted central server) with conflict resolution rules. |
| Import hygiene (dedupe, filename parsing, broken-path handling) | Real-world libraries are messy; users expect app to cope | HIGH | Fingerprint + path-based matching; quarantine unresolved items; surface actionable fix UI. |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Serverless-first architecture with user-controlled storage only | Strong privacy story; no hosted lock-in; lower trust barrier | HIGH | Make all critical flows work without vendor backend except optional OAuth/token flows. |
| Unified cross-storage "single library" with transparent source fallback | Users can blend NAS + cloud + external servers as one collection | HIGH | Storage abstraction plus source health scoring and per-item preferred-source selection. |
| Media-type aware metadata fusion (movie/TV/anime/adult optional) | Better match quality than one-size-fits-all scrapers | HIGH | Rule engine for source precedence by media type; opt-in adult metadata providers with strict isolation. |
| Privacy controls by design (per-source encryption at rest, local-only mode, explicit telemetry off by default) | Differentiates for privacy-first users | MEDIUM | Requires clear settings UX, secure token vault, and no hidden network calls in local-only mode. |
| Fast re-scan strategy (incremental + change detection) | Massive quality-of-life for large libraries | MEDIUM | Track signatures/mtime/hash tiers and do staged scans to avoid full rescans. |
| Resume continuity heuristics (file moved/renamed but still same media) | Reduces frustration in actively managed libraries | MEDIUM | Use fingerprinting and metadata confidence matching to carry progress across path changes. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Built-in torrent/indexer integration | "One app for everything" appeal | Conflicts with legal/product stance; raises platform risk and support burden | Keep strict import-only model for user-owned media files and documented folder watch workflows. |
| Mandatory hosted account + central media server | Easier sync story at first glance | Violates serverless-first/privacy intent; adds infra/ops/security overhead | Use optional sign-in for provider auth only; sync via user-owned storage profile. |
| Remote transcoding service operated by product | Helps weak client devices | Expensive infra, hard QoS, and undermines serverless architecture | Prefer direct play + optional user-managed transcode endpoint plugins later. |
| Full social network layer (public profiles, comments, feeds) | Engagement buzz | Distracts from core jobs-to-be-done and increases moderation/compliance scope | Offer lightweight local insights and optional export/share snapshots. |
| Auto-magic metadata overwrite with no user control | "Set and forget" promise | Wrong matches destroy trust and cause cleanup pain | Default to confidence thresholds + review queue + per-item lock/manual override. |

## Feature Dependencies

```
Storage Adapter Layer
    └──requires──> Credential Vault + Source Auth
                           └──requires──> Platform Secure Storage Integration

Metadata Enrichment
    └──requires──> Ingest + Filename/Folder Parsing
                           └──requires──> Unified Media Identity Model

Playback + Resume
    └──requires──> Unified Media Identity Model
                           └──requires──> Local State Store

Cross-Device Sync
    └──requires──> Local State Store
                           └──requires──> Conflict Resolution Policy

Offline Browsing ──enhances──> Library Browsing/Search
Incremental Re-scan ──enhances──> Multi-source Ingest

Aggressive Auto-Metadata Overwrite ──conflicts──> User Trust + Manual Curation
Hosted Central Server ──conflicts──> Serverless-first Product Direction
```

### Dependency Notes

- **Metadata Enrichment requires Ingest + Parsing:** metadata quality depends on normalized filenames, folder context, and canonical media IDs from ingest.
- **Playback + Resume requires Unified Media Identity Model:** resume can only survive moves/renames if identity is not path-only.
- **Cross-Device Sync requires Conflict Resolution Policy:** progress/settings updates from multiple devices must merge deterministically.
- **Offline Browsing enhances Library Browsing/Search:** same local index powers both online and offline discovery.
- **Hosted Central Server conflicts with serverless-first direction:** introduces persistent backend obligations and trust/legal surface the product is intentionally avoiding.

## MVP Definition

### Launch With (v1)

Minimum viable product - what's needed to validate the concept.

- [x] Multi-source ingest for local + OneDrive + SFTP/WebDAV (FTP optional behind flag) - validates core "single library from owned storage" promise.
- [x] Metadata enrichment with manual correction flow - protects trust while delivering usable libraries.
- [x] Playback with stable resume/progress + local persistence - makes app viable as a daily player.
- [x] Basic browse/search/filter with offline cache - supports practical use on unreliable networks.
- [x] Optional sync of watch progress/settings across devices via user-controlled sync target - validates multi-device value without hosted backend.

### Add After Validation (v1.x)

Features to add once core is working.

- [ ] Incremental re-scan optimization - add when import scale pain appears in telemetry/feedback.
- [ ] Resume continuity across moved/renamed files - add after identity model proves stable in production.
- [ ] Advanced collection organization (smart collections, rules) - add when baseline navigation metrics flatten.
- [ ] Optional adult-library isolation mode - add once consent, profile separation, and metadata safety UX are hardened.

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] User-managed transcode endpoint plugins - defer due to complexity and support burden.
- [ ] Watch-party/real-time co-view - defer because it requires network/session architecture outside core focus.
- [ ] Recommendation engine beyond simple similarity - defer until enough interaction data and explicit consent model exist.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Multi-source ingest adapters | HIGH | HIGH | P1 |
| Metadata enrichment + manual fix flow | HIGH | MEDIUM | P1 |
| Playback + resume | HIGH | MEDIUM | P1 |
| Offline browse/search cache | HIGH | MEDIUM | P1 |
| Cross-device progress/settings sync (serverless) | HIGH | HIGH | P1 |
| Incremental re-scan | MEDIUM | MEDIUM | P2 |
| Smart collections/rules | MEDIUM | MEDIUM | P2 |
| Adult-library isolation (opt-in) | MEDIUM | HIGH | P2 |
| Transcode endpoint plugins | LOW | HIGH | P3 |
| Watch-party/co-view | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | Competitor A (Plex) | Competitor B (Jellyfin) | Our Approach |
|---------|----------------------|-------------------------|--------------|
| Core architecture | Server-oriented, account-centric ecosystem | Self-hosted server required | Serverless-first client with user-owned storage and optional sync target |
| Multi-source ingest | Strong for local/server paths; cloud workflows less unified | Strong for server-mounted libraries | First-class mixed-source ingest (local + cloud + remote protocols) as a single logical library |
| Metadata model | Broad movie/TV support, centralized metadata behavior | Good open-source metadata agents, server-managed | Media-type aware fusion (movie/TV/anime, optional adult) with explicit manual control |
| Privacy posture | Cloud-connected features by default for best experience | Better self-hosting control but server required | Local-first operation, explicit opt-in network features, telemetry off by default |

## Sources

- Product context provided for Freak-Flix initialization research (scope + non-goals)
- Public feature positioning of Plex and Jellyfin product docs/sites (high-level pattern reference)
- General domain patterns from media manager/player ecosystems (2024-2026)

---
*Feature research for: personal media library manager/player (serverless-first, multi-storage)*
*Researched: 2026-02-27*
