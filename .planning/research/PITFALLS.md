# Pitfalls Research

**Domain:** Media library manager with local/cloud ingestion and cross-platform playback
**Researched:** 2026-02-27
**Confidence:** MEDIUM-HIGH

## Critical Pitfalls

### Pitfall 1: Naive Polling Triggers Provider Throttling and Sync Storms

**What goes wrong:**
The app repeatedly rescans remote drives (OneDrive/WebDAV/etc.) with full listings, hits 429/503 limits, then retries aggressively and amplifies failures. Metadata freshness gets worse as traffic rises.

**Why it happens:**
Teams ship with simple interval polling and no delta/change token strategy, then add retries without global backoff coordination.

**How to avoid:**
Adopt change-tracking first (delta tokens/checkpoints) and webhook-driven wakeups where available; enforce global per-provider rate budgets; honor `Retry-After`; use jittered exponential backoff; persist sync cursors durably.

**Warning signs:**
- Frequent HTTP 429/503 responses from provider APIs
- Spikes of repeated list calls for unchanged folders
- Sync queue growth despite low real content churn
- "Catch-up" jobs running continuously after brief outages

**Phase to address:**
Phase 1 (Ingestion Foundation) + Phase 2 (Provider Integrations Hardening). Build throttling-safe sync core before broad connector rollout.

---

### Pitfall 2: OneDrive Auth Edge Cases Cause Silent De-Authorization

**What goes wrong:**
Users appear connected, but refresh fails (token revoked/expired/claims changed), sync stalls, and playback paths break until manual reconnect.

**Why it happens:**
Token lifecycle and conditional access behaviors are treated as happy-path only; apps do not classify auth errors or design re-consent UX.

**How to avoid:**
Use authorization code + PKCE for public clients; store token metadata and last successful refresh timestamps; classify 401/403/insufficient-claims flows; add explicit reconnect state machine; provide "re-auth needed" UX with safe degradation.

**Warning signs:**
- Sudden increase in 401/403 errors for previously healthy accounts
- Repeated failed refresh attempts for the same account
- Accounts stuck in "syncing" without progress
- Support tickets: "connected account shows empty library"

**Phase to address:**
Phase 2 (Provider Integrations Hardening). Do not mark OneDrive integration complete without revocation and re-consent scenarios.

---

### Pitfall 3: Full-Scan Library Indexing Collapses at Scale

**What goes wrong:**
Large libraries (50k+ items) cause long startup scans, UI freezes, duplicate records, battery/network drain, and abandoned sessions.

**Why it happens:**
Monolithic scan jobs, synchronous metadata enrichment, and no checkpointed incremental indexing.

**How to avoid:**
Split discovery/index/enrichment into resumable stages; prioritize visible/active paths first; cap concurrent I/O per provider; use incremental hashing/fingerprints and idempotent upserts; isolate indexing in background workers.

**Warning signs:**
- First sync times measured in hours, not minutes
- Memory growth during scans without release
- Duplicate media entries after interrupted sync
- Playback stutter while indexing is active

**Phase to address:**
Phase 1 (Ingestion Foundation). Performance architecture must be in MVP, not deferred.

---

### Pitfall 4: Metadata Mis-Match Erodes Trust Quickly

**What goes wrong:**
Wrong titles/posters/episode mapping appear due to weak matching logic, poor confidence thresholds, and source disagreement. Users stop trusting automation.

**Why it happens:**
Filename-only matching, no confidence model, and no human override workflow.

**How to avoid:**
Use deterministic local identifiers first (file path + fingerprint); apply multi-signal matching (title/year/season/episode/runtime); require confidence thresholds before auto-apply; keep reversible metadata decisions and user override pinning.

**Warning signs:**
- High rate of manual metadata corrections
- Frequent rematches on rescan for same file
- Multiple external IDs attached to same logical item
- User reports of "poster roulette"

**Phase to address:**
Phase 3 (Metadata Quality and UX Controls). Ship correction tools alongside matching automation.

---

### Pitfall 5: Security Regression via Path/Command Injection in Storage Connectors

**What goes wrong:**
Unsafe path handling or shell invocation in FTP/SFTP/WebDAV/local adapters enables command/path traversal, credential leakage, or arbitrary file access.

**Why it happens:**
Connector implementations normalize paths inconsistently, trust remote names, or compose shell commands unsafely during probes/transcoding helpers.

**How to avoid:**
Centralize path canonicalization and validation; ban shell interpolation for file ops; enforce allowlisted schemes and root boundaries; fuzz malformed path inputs; keep security tests as release gates.

**Warning signs:**
- Security tests start failing after connector refactors
- Paths containing `..`, mixed separators, or encoded traversal pass validation
- Crash logs around unexpected URI parsing branches
- New helper scripts introduced for core file operations

**Phase to address:**
Phase 0 (Security Baseline) + continuous in every phase. Security regression checks must be CI-blocking.

---

### Pitfall 6: Privacy Boundary Violations for Adult Opt-In Content

**What goes wrong:**
Adult-tagged media appears in previews/search/recommendations before consent, or consent state leaks across profiles/devices unexpectedly.

**Why it happens:**
Adult gating is implemented as UI-only filtering instead of a full data-access policy; logs/telemetry include sensitive labels.

**How to avoid:**
Treat adult visibility as a policy layer across query, cache, thumbnails, and notifications; require explicit opt-in per profile; default-deny in shared contexts; minimize and redact sensitive telemetry fields.

**Warning signs:**
- Adult items visible in global search before opt-in
- Thumbnails generated for restricted libraries in shared caches
- Telemetry containing raw explicit titles/tags
- Consent toggles not respected after app restart

**Phase to address:**
Phase 0 (Policy & Safety Guardrails) and verified again in Phase 4 (Cross-Platform UX QA).

---

### Pitfall 7: Legal/Policy Drift Around Metadata Providers

**What goes wrong:**
App usage drifts outside provider terms (attribution missing, unsupported commercial usage assumptions, prohibited content contexts), creating takedown or key revocation risk.

**Why it happens:**
Teams treat API keys as purely technical and ignore attribution, acceptable-use, and business-use constraints over time.

**How to avoid:**
Track provider policy obligations as code-adjacent compliance checklist; enforce attribution surfaces in-app; separate non-commercial and commercial configuration paths; review terms on release cadence.

**Warning signs:**
- Attribution missing in About/Credits after redesigns
- API key reused across test/prod without usage governance
- New monetization plans without provider-terms review
- Provider support warnings about usage pattern

**Phase to address:**
Phase 0 (Policy & Safety Guardrails) with release-time compliance checks each milestone.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Full rescan every launch | Easy correctness story | Unusable at large library size; API throttling | Only for local dev fixtures |
| Provider-specific retry logic scattered in adapters | Quick integration | Inconsistent behavior and untestable edge cases | Never |
| Store opaque token blobs without lifecycle metadata | Faster coding | Impossible auth diagnostics/recovery | Never |
| Filename-only metadata match | Fast MVP demo | Persistent mis-matches and user distrust | MVP only with explicit "low confidence" UI |
| UI-only adult filter | Faster release | Privacy violations and policy risk | Never |

## Integration Gotchas

Common mistakes when connecting to external services.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| OneDrive / Microsoft Graph | Polling full trees + immediate retries on 429 | Delta/query tokens + webhook hints + Retry-After compliance + jittered backoff |
| TMDB | Assuming unlimited free/commercial use and skipping attribution | Enforce attribution + review business usage terms and API notices at release checkpoints |
| AniList | Treating rate limits as static and globally uniform | Read headers (`X-RateLimit-*`, `Retry-After`) and make quotas runtime-configurable |
| FTP/WebDAV | Assuming modern security defaults across servers | Prefer secure transports, explicit TLS policy, and strict credential/path handling |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Single-threaded ingest + metadata enrichment | Long blocking scans, frozen UI | Pipeline and background workers with bounded concurrency | ~10k-20k items |
| No cache invalidation strategy for thumbnails/metadata | Stale posters, cache bloat | Versioned cache keys + eviction policy + selective busting | ~50k assets |
| Unbounded retry queues during provider outages | Queue explosion, delayed recovery | Circuit breakers + dead-letter handling + backpressure | First prolonged outage |
| N+1 API lookups per item | Slow sync, quota burn | Batch endpoints or staged enrichment | Any remote provider at scale |

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Persisting cloud refresh tokens unencrypted at rest | Account takeover from local compromise | OS keychain/credential vault + token scope minimization |
| Trusting remote path/filename input in file ops | Traversal/injection and arbitrary access | Canonicalization + root enforcement + strict validation |
| Logging provider auth errors with tokens/PII | Secret exposure in logs | Structured redaction and secure logging policy |
| No privilege separation between browsing and restricted content policies | Adult content disclosure or bypass | Policy-enforced query layer and per-profile authorization checks |

## UX Pitfalls

Common user experience mistakes in this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Showing "Sync complete" while background retries continue | False confidence and confusion | Show staged status (discovered/indexed/enriched/failed) |
| Generic "Playback failed" for remote stream timeouts | Support burden and churn | Surface actionable causes (auth expired, network slow, format unsupported) |
| Hidden metadata confidence | Users cannot trust auto-match | Expose confidence and one-tap correct/lock actions |
| Adult opt-in buried in settings without clear state | Accidental exposure or overblocking | Explicit onboarding gate and visible profile-level status |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **OneDrive integration:** Handles token revocation, conditional-access claims, and reconnect UX
- [ ] **Sync engine:** Persists and restores delta cursors after crash/restart
- [ ] **Metadata pipeline:** Supports manual correction with lock/pin against rematch
- [ ] **Adult opt-in:** Enforced in search, thumbnails, recommendations, and notifications
- [ ] **Security hardening:** Path traversal/injection tests run in CI for all storage adapters
- [ ] **Policy compliance:** Attribution and provider-terms checks included in release checklist

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Throttling-induced sync backlog | MEDIUM | Pause aggressive jobs, apply global backoff, replay from latest known cursor, and throttle re-enrichment |
| Token revocation wave (provider-side) | MEDIUM | Bulk-detect stale sessions, prompt scoped re-auth, preserve local catalog while cloud paths are disabled |
| Metadata corruption/mis-match batch | HIGH | Roll back to last metadata snapshot, re-run matcher with stricter confidence, enable assisted review queue |
| Privacy breach for restricted content | HIGH | Immediate feature flag lockdown, purge restricted caches/logs, force policy re-evaluation, incident review |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Throttling and sync storms | Phase 1-2 | Load tests include 429/503 chaos and prove bounded retries |
| OneDrive auth edge cases | Phase 2 | Automated tests for refresh expiry, revoked tokens, and `insufficient_claims` flows |
| Large-library collapse | Phase 1 | Benchmark targets met at 10k/50k libraries with resumable indexing |
| Metadata mis-match | Phase 3 | Match precision/recall metrics + manual correction retention tests |
| Security regression in connectors | Phase 0 + continuous | CI security suite passes traversal/injection corpus each release |
| Adult opt-in privacy leakage | Phase 0 + 4 | Policy test matrix validates deny-by-default across all surfaces |
| Provider legal/policy drift | Phase 0 + release governance | Release checklist contains attribution and terms review sign-off |

## Sources

- [HIGH] Microsoft Graph throttling guidance (429, Retry-After, anti-polling guidance): https://learn.microsoft.com/en-us/graph/throttling
- [HIGH] OneDrive scan guidance (delta + webhook patterns, throttling behavior): https://learn.microsoft.com/en-us/onedrive/developer/rest-api/concepts/scan-guidance?view=odsp-graph-online
- [HIGH] Microsoft Graph error model (`insufficient_claims`, 401/403 handling context): https://learn.microsoft.com/en-us/graph/errors
- [HIGH] Microsoft identity platform auth code + PKCE + refresh token behavior: https://learn.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-auth-code-flow
- [MEDIUM] Microsoft refresh token lifetime/revocation article (access-controlled page, content retrieved via web mirror): https://learn.microsoft.com/en-us/entra/identity-platform/refresh-tokens
- [HIGH] TMDB API rate-limiting note and `429` guidance: https://developer.themoviedb.org/docs/rate-limiting
- [HIGH] TMDB FAQ attribution and usage/legal notice: https://developer.themoviedb.org/docs/faq
- [MEDIUM] TMDB Terms of Use and API usage constraints context: https://www.themoviedb.org/terms-of-use
- [HIGH] AniList rate-limiting headers and temporary degraded quota notice: https://docs.anilist.co/guide/rate-limiting
- [HIGH] Provider package changelog (recent behavior changes affecting MultiProvider and read semantics): https://pub.dev/packages/provider/changelog
- [HIGH] Google Play policy constraints for sexual content and age-restricted distribution contexts: https://support.google.com/googleplay/android-developer/answer/9878810
- [HIGH] GDPR legal text (EU Regulation 2016/679) for data minimization and confidentiality principles: https://eur-lex.europa.eu/eli/reg/2016/679/oj/eng

---
*Pitfalls research for: media library manager with local/cloud ingestion and cross-platform playback*
*Researched: 2026-02-27*
