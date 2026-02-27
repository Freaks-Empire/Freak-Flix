# Project Research Summary

**Project:** Freak-Flix
**Domain:** Cross-platform, serverless-first personal media library manager/player
**Researched:** 2026-02-27
**Confidence:** MEDIUM

## Executive Summary

Freak-Flix is best built as an offline-first Flutter client that treats local and user-owned remote storage as the source of truth, not a hosted product backend. The research converges on a layered architecture (UI -> use cases/coordinators -> repositories/adapters -> persistence/runtime), with a canonical media identity model at the core so ingest, metadata, playback resume, and cross-device sync all operate on the same stable IDs.

The recommended approach is to lock the existing stack (Flutter 3.38.4 / Dart 3.10.3, Provider, go_router, media_kit, Drift) and sequence delivery by dependency: security/policy guardrails first, then ingestion + local catalog + playback persistence, then provider-specific hardening and sync conflict handling, then metadata trust UX and scale optimizations. This order matches architecture constraints and minimizes expensive rework.

The biggest risks are sync storms from naive polling, auth edge cases (especially OneDrive token lifecycle), large-library scan collapse, metadata mismatch trust erosion, and connector security regressions (path traversal/command injection/SSRF). Mitigation is explicit in the research: delta/cursor-based sync with bounded retries, deterministic conflict policy, resumable staged indexing, confidence-based metadata application with manual lock/pin controls, and CI-blocking security tests across all adapters.

## Key Findings

### Recommended Stack

Research strongly supports continuing the current Flutter-first baseline rather than introducing architecture churn. The technical center is Provider + go_router for app flow, media_kit for playback parity, and Drift for a queryable local catalog that supports offline browsing and sync queues.

**Core technologies:**
- `Flutter 3.38.4` + `Dart 3.10.3`: cross-platform runtime baseline already established in-repo with low migration risk.
- `Provider 6.1.5+1`: existing state-management model; enables incremental scaling without full state rewrite.
- `go_router 17.1.0`: stable declarative navigation with deep-link/web URL support.
- `media_kit` + `media_kit_video`: broad codec/platform coverage for local + remote playback.
- `Drift 2.31.0`: typed local DB for catalog/search/resume/sync queues; better fit than key-value or mobile-only DB patterns.

Critical version constraints: pin Flutter/Dart toolchain, keep media_kit platform libs aligned, and account for Drift web WASM deployment requirements (including header constraints that can conflict with popup auth flows).

### Expected Features

The product must prove one core promise at launch: users can unify their own storage sources into a single reliable, metadata-rich library with strong playback continuity and no mandatory hosted server.

**Must have (table stakes):**
- Multi-source ingest across local + OneDrive + SFTP/WebDAV (FTP as optional/legacy).
- Metadata enrichment with manual correction/override controls.
- Reliable playback with resume/progress persistence.
- Browse/search/filter backed by offline-capable local index/cache.
- Optional cross-device sync (watch progress/settings) via user-controlled targets.

**Should have (competitive):**
- Transparent cross-storage fallback and source health behavior.
- Media-type-aware metadata fusion (movie/TV/anime; optional adult isolation path).
- Privacy-by-default controls (local-only mode, explicit telemetry opt-in).
- Incremental rescans and moved/renamed-file resume continuity.

**Defer (v2+):**
- Product-operated transcoding, watch-party/co-view, and heavy recommendation systems.
- Social-network style surface area.

### Architecture Approach

The architecture recommendation is clear: keep UI providers thin, move logic into use cases/coordinators, and isolate all storage/protocol/provider volatility behind repository contracts. Build from domain models outward (canonical identity -> repositories -> local persistence -> remote adapters -> metadata pipeline -> sync engine -> playback state machine -> UI), then add platform scheduler bindings.

**Major components:**
1. `ScanCoordinator` — staged discovery/diff/index job orchestration with bounded concurrency.
2. `MetadataPipeline` — canonical normalization + provider sidecars + confidence-based merge behavior.
3. `SyncCoordinator` — cursor/delta tracking, validator checks, and deterministic conflict policy.
4. `PlaybackStateMachine` — event-driven resume/checkpoint lifecycle and queue state.
5. `CredentialManager` — secure token/secret handling with lifecycle metadata.

### Critical Pitfalls

1. **Sync storms from naive polling** — prevent with delta tokens, global budgets, `Retry-After` compliance, and jittered backoff.
2. **OneDrive auth silent failure** — prevent with PKCE, token lifecycle telemetry, and explicit reconnect UX state machine.
3. **Large-library full-scan collapse** — prevent with resumable staged indexing, idempotent upserts, and background workers.
4. **Metadata mismatch trust failure** — prevent with confidence thresholds, reversible decisions, and manual lock/pin controls.
5. **Connector security regressions** — prevent with centralized path validation, no shell interpolation, SSRF controls, and CI security gates.

## Implications for Roadmap

Based on cross-file dependencies, a five-phase roadmap is the most defensible sequence.

### Phase 0: Security, Policy, and Domain Baseline
**Rationale:** Every later phase depends on safe path/URL handling, privacy policy enforcement, and canonical identity semantics.
**Delivers:** Security baseline (traversal/injection/SSRF protections), compliance checklist (attribution/terms), adult-content policy framework, canonical media identity and domain contracts.
**Addresses:** Foundations for all P1 features; anti-feature boundaries (no hosted mandatory backend/torrent scope).
**Avoids:** Security regression, policy drift, privacy leaks.

### Phase 1: Ingestion + Local Catalog + Playback Persistence
**Rationale:** Ingest and stable local state are prerequisites for metadata quality, offline UX, and sync correctness.
**Delivers:** Multi-source scan pipeline (local + selected remotes), resumable indexing, Drift catalog/search index, basic offline browse/search, playback state machine with durable resume.
**Addresses:** Table-stakes ingest, browse/search, playback+resume, offline browsing.
**Avoids:** Full-scan collapse, UI blocking, queue explosion from poor staging.

### Phase 2: Provider Hardening + Serverless Sync
**Rationale:** Once local-first core is stable, add network complexity with deterministic sync semantics.
**Delivers:** OneDrive/SFTP/WebDAV hardening, auth/reconnect flows, delta-cursor sync engine, conflict-resolution policies for progress/settings, retry/backoff governance.
**Uses:** `go_router` guards for auth states, secure storage for token lifecycle, repository adapter boundaries.
**Implements:** `SyncCoordinator` + credential lifecycle management.
**Avoids:** Throttling storms and silent de-authorization.

### Phase 3: Metadata Quality and Trust UX
**Rationale:** Automation without trust controls harms retention; quality should follow stable ingest/sync identity.
**Delivers:** Multi-provider metadata fusion, confidence scoring, review queue, lock/pin/manual correction UX, mismatch diagnostics.
**Addresses:** Metadata enrichment P1 quality bar and key differentiator around user control.
**Avoids:** Poster/title mismatches and repeated rematch churn.

### Phase 4: Scale Optimization and Differentiators
**Rationale:** Performance tuning and advanced capabilities are highest ROI after baseline reliability metrics are proven.
**Delivers:** Incremental rescans, move/rename resume continuity, source fallback scoring, optional advanced collections, optional adult-library isolation hardening.
**Addresses:** P2 differentiators and large-library usability.
**Avoids:** Premature complexity and unbounded support burden.

### Phase Ordering Rationale

- Domain identity, security, and policy controls must precede adapter and UX expansion to avoid rework and regressions.
- Ingestion/catalog/playback form the dependency backbone for metadata and sync; building them first reduces downstream complexity.
- Provider hardening belongs after local-first stability because most critical pitfalls are integration-edge behaviors.
- Metadata trust tooling should ship with automation maturity, not before stable identity and sync.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2:** OneDrive auth lifecycle edge cases (`insufficient_claims`, revoked refresh tokens), provider-specific throttling semantics, and webhook/delta strategy details.
- **Phase 3:** Metadata precision/recall tuning and confidence-threshold calibration across TMDB/AniList/StashDB.
- **Phase 4:** Adult-content policy matrix across platforms and compliance implications for distribution channels.

Phases with standard patterns (can likely skip extra research-phase):
- **Phase 0:** Security baseline patterns (OWASP controls, secure storage norms) are well-established.
- **Phase 1:** Flutter layered architecture + offline-first repository + local DB indexing are well-documented.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Strongly backed by official package/docs and validated against repo baseline toolchain. |
| Features | MEDIUM | Good domain alignment, but some competitive assumptions are from high-level ecosystem patterns rather than primary technical specs. |
| Architecture | HIGH | Supported by Flutter architecture guidance and concrete, testable boundary patterns. |
| Pitfalls | HIGH | Major risks map to authoritative provider/security guidance with clear warning signs and mitigations. |

**Overall confidence:** MEDIUM

### Gaps to Address

- **Web auth vs WASM constraints:** validate whether Drift WASM hosting/header requirements conflict with chosen OneDrive web auth flow in production hosting.
- **Sync target contract details:** finalize exact user-owned sync document schema, quota expectations, and conflict telemetry.
- **Metadata quality KPIs:** define launch thresholds (precision/recall/manual-correction rate) before broad auto-apply.
- **Adult-content policy implementation matrix:** confirm per-platform distribution policy boundaries and local cache redaction behavior.

## Sources

### Primary (HIGH confidence)
- Flutter official architecture and persistence guidance (`docs.flutter.dev`) — layered architecture, key-value vs SQLite boundaries, isolate usage.
- Pub.dev docs for `provider`, `go_router`, `media_kit`, `drift`, `flutter_secure_storage` — package capabilities and constraints.
- Microsoft Graph/OneDrive docs — throttling, delta query/scan guidance, auth and error models.
- OWASP guidance — command injection, path traversal, SSRF prevention controls.

### Secondary (MEDIUM confidence)
- TMDB and AniList public developer docs/FAQs — rate limits, attribution/commercial usage caveats.
- WebDAV RFC references and cross-provider behavior assumptions.
- Competitor landscape (Plex/Jellyfin) used as directional benchmark, not implementation spec.

### Tertiary (LOW confidence)
- None material; low-confidence claims were excluded from roadmap-critical recommendations.

---
*Research completed: 2026-02-27*
*Ready for roadmap: yes*
