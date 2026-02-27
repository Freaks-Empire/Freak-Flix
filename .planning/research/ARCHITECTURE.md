# Architecture Research

**Domain:** Cross-platform Flutter personal media app (offline-first + remote storage streaming)
**Researched:** 2026-02-27
**Confidence:** HIGH

## Standard Architecture

### System Overview

```text
┌─────────────────────────────────────────────────────────────────────────┐
│ Presentation Layer (Flutter)                                           │
├─────────────────────────────────────────────────────────────────────────┤
│  Screens  │  Widgets  │  Router  │  View Models (Provider)            │
└───────────────┬───────────────────────────────┬─────────────────────────┘
                │ intents/state updates         │ playback events
┌───────────────┴───────────────────────────────┴─────────────────────────┐
│ Application Layer (Use Cases + Coordinators)                            │
├─────────────────────────────────────────────────────────────────────────┤
│  LibraryScanCoordinator  MetadataPipeline  SyncCoordinator  PlaybackSM  │
└───────────────┬───────────────────────────────┬─────────────────────────┘
                │ repository contracts          │ job dispatch
┌───────────────┴───────────────────────────────┴─────────────────────────┐
│ Data/Infra Layer                                                        │
├─────────────────────────────────────────────────────────────────────────┤
│  CatalogRepo  FileIndexRepo  PlaybackStateRepo  CredentialRepo          │
│  Local FS adapter  OneDrive/SFTP/FTP/WebDAV/Drive adapters             │
│  TMDB/AniList/StashDB adapters  MediaKit adapter  Scheduler adapter     │
└───────────────┬───────────────────────────────┬─────────────────────────┘
                │ read/write state              │ stream bytes
┌───────────────┴───────────────────────────────┴─────────────────────────┐
│ Persistence + Runtime                                                   │
├─────────────────────────────────────────────────────────────────────────┤
│  SQLite-class catalog store  cache dir  shared_preferences (settings)   │
│  flutter_secure_storage (secrets)  isolate workers  platform schedulers │
└─────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| `ScanCoordinator` | Walk local/remote trees, diff snapshots, enqueue metadata and sync work | App service using isolate workers + scheduler adapter |
| `MetadataPipeline` | Normalize metadata into one canonical media model and cache provider payloads | Deterministic normalizers + repository cache with TTL |
| `SyncCoordinator` | Resolve local/remote divergence, apply conflict policy, persist sync cursor/token | Per-backend adapter plus shared conflict engine |
| `PlaybackStateMachine` | Own playback lifecycle, resume checkpoints, last position, and queue state | Provider + MediaKit event bridge + debounced persistence |
| `CredentialManager` | Read/write encrypted secrets and token metadata only | `flutter_secure_storage` facade with platform options |

## Recommended Project Structure

```text
lib/
├── app/                     # App bootstrap, DI wiring, router composition
│   ├── bootstrap/           # startup order, migrations, feature flags
│   └── routing/             # go_router route tree and guards
├── features/                # Vertical feature slices
│   ├── library/             # scan/index/browse use cases + UI
│   ├── playback/            # player screen, controls, playback provider
│   ├── sync/                # remote sync and conflict workflows
│   └── settings/            # storage connections, account settings
├── domain/                  # Pure models, value objects, policies
│   ├── media/               # canonical media identity + metadata contracts
│   ├── sync/                # conflict policies, merge outcomes
│   └── playback/            # playback session and resume policy
├── data/                    # Repository implementations and adapters
│   ├── local/               # file system and local DB/cache adapters
│   ├── remote/              # OneDrive/SFTP/FTP/WebDAV/Drive adapters
│   ├── metadata/            # TMDB/AniList/StashDB clients
│   └── security/            # secure storage adapter and token handling
├── jobs/                    # background task entrypoints and job runners
│   ├── scheduler/           # workmanager/in-app scheduler abstraction
│   └── workers/             # isolate-friendly pure job handlers
└── shared/                  # common widgets, utils, telemetry, errors
```

### Structure Rationale

- **`features/`:** Keeps app behavior discoverable by user workflow instead of by technical layer only.
- **`domain/`:** Prevents storage/backend details from leaking into UI and keeps sync/conflict policy testable.
- **`data/`:** Isolates protocol and provider churn (Drive/WebDAV/metadata APIs) behind stable repository contracts.
- **`jobs/`:** Decouples background execution constraints from business logic to preserve platform consistency.

## Suggested Build & Dependency Order

```text
1. Domain models/policies
   -> 2. Repository interfaces
      -> 3. Local persistence (catalog + playback + cache)
         -> 4. Remote adapters (OneDrive/SFTP/FTP/WebDAV/Drive)
            -> 5. Metadata pipeline + normalization
               -> 6. Scan/sync coordinators + conflict engine
                  -> 7. Playback state machine integration
                     -> 8. UI providers/screens
                        -> 9. Background scheduler bindings per platform
```

Why this order: conflict logic and playback persistence depend on stable identities, and stable identities depend on canonical domain models + repository boundaries first.

## Architectural Patterns

### Pattern 1: Offline-First Repository with Stale-While-Revalidate

**What:** UI always reads from local catalog first; background jobs refresh and reconcile remote changes.
**When to use:** Every browse/list/detail surface where responsiveness is critical.
**Trade-offs:** Great UX and resilience; requires robust invalidation and sync cursor management.

**Example:**
```dart
Future<List<MediaItem>> getLibraryPage(Query q) async {
  final local = await catalogRepo.query(q);
  unawaited(syncCoordinator.refreshIfNeeded(q.scope));
  return local;
}
```

### Pattern 2: Canonical Media Identity + Provider-Specific Enrichment

**What:** Keep one canonical media entity (local path/hash + normalized title/year/type), attach TMDB/AniList/StashDB enrichments as sidecars.
**When to use:** Metadata merge, dedupe, and cache invalidation.
**Trade-offs:** Avoids provider lock-in and merge chaos; adds upfront normalization work.

**Example:**
```dart
class CanonicalMediaId {
  final String contentHash;
  final String mediaType;
  final int? year;
}
```

### Pattern 3: Conflict Resolution by Validator + Deterministic Policy

**What:** Use ETag/mtime/remote cursor as version validators; run deterministic policy (`lastWriteWins`, `manualReview`, or `metadataMerge`).
**When to use:** Two-way sync for watch progress, playlists, and edited metadata.
**Trade-offs:** Deterministic outcomes and fewer surprises; policy exceptions must be explicit.

## Data Flow

### Request Flow

```text
[User opens Library]
    ↓
[LibraryScreen] -> [LibraryProvider] -> [QueryLibraryUseCase] -> [CatalogRepo]
    ↓                     ↓                     ↓                  ↓
[Render items]   [dispatch refresh]   [SyncCoordinator]   [Local DB + cache]
                                             ↓
                                   [Remote adapters + metadata APIs]
```

### State Management

```text
[Provider store]
    ↓ (watch/select)
[Widgets] <-> [User intents] -> [Use cases] -> [Repositories] -> [Provider notify]
```

### Key Data Flows

1. **Background scan flow:** Scheduler trigger -> scan job -> isolate file listing -> snapshot diff -> catalog upsert -> metadata enqueue.
2. **Metadata normalization flow:** New/changed file -> extractor/provider lookup -> canonical normalize -> conflict-safe merge -> cache + index update.
3. **Playback persistence flow:** MediaKit stream events -> playback state machine -> debounced checkpoint write -> sync queue for remote progress.
4. **Sync conflict flow:** Remote delta token fetch -> compare validators -> apply policy -> persist resolution + new cursor.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 0-10k items | Single local catalog DB, one scan queue, simple retry logic |
| 10k-250k items | Partition index by storage backend + media type; batch metadata writes; tune isolate pool |
| 250k+ items | Incremental scan checkpoints per subtree, adaptive backoff per backend, cache compaction + cold-tier metadata |

### Scaling Priorities

1. **First bottleneck:** metadata fetch/normalize latency; fix with queue backpressure and provider result caching.
2. **Second bottleneck:** scan + DB write amplification; fix with chunked diffing and batched transactions.

## Anti-Patterns

### Anti-Pattern 1: Provider Calling Remote APIs Directly

**What people do:** Put API calls inside UI providers/widgets for convenience.
**Why it&#x27;s wrong:** Breaks testability, duplicates retry/auth logic, and creates inconsistent conflict behavior.
**Do this instead:** Providers call use cases only; use cases depend on repository contracts.

### Anti-Pattern 2: Using Key-Value Storage as Primary Catalog

**What people do:** Keep large media index in `shared_preferences` style blobs.
**Why it&#x27;s wrong:** Official Flutter guidance positions key-value persistence for relatively small key/value sets.
**Do this instead:** Keep settings in key-value store; store library index in a queryable local DB.

### Anti-Pattern 3: Assuming One Background Strategy Works Everywhere

**What people do:** Build around one mobile scheduler and expect desktop/web parity.
**Why it&#x27;s wrong:** `workmanager` package supports Android/iOS; desktop/web need app-driven scheduling.
**Do this instead:** Use a scheduler abstraction with per-platform implementations.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| OneDrive / Google Drive | Delta-token incremental sync + cursor persistence | Prefer delta/change APIs over full tree relist |
| SFTP / FTP / WebDAV | Adapter + normalized remote file model + conditional updates where supported | Use ETag/mtime/lock semantics for conflict checks |
| TMDB / AniList / StashDB | Read-through cache with normalization pipeline | Keep provider payload as sidecar, not canonical truth |
| Media playback engine (`media_kit`) | Event stream bridge into playback state machine | Persist checkpoints on debounced position updates |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `features/*` -> `domain/*` | direct imports of pure models | No adapter/protocol classes allowed in UI layer |
| `application/usecases` -> `data/repositories` | interface contracts | Enables local-only and remote-enabled modes with same UI |
| `jobs/workers` -> `application/coordinators` | command payloads + DTOs | Keep worker entrypoints isolate-safe and deterministic |

## Sources

- Flutter app architecture guide (recommended layered architecture, MVVM/state guidance), updated 2025-09-05: https://docs.flutter.dev/app-architecture (HIGH)
- Flutter cookbook: key-value storage is for relatively small sets, SQLite for larger query workloads: https://docs.flutter.dev/cookbook/persistence/key-value and https://docs.flutter.dev/cookbook/persistence/sqlite (HIGH)
- Flutter isolates/performance docs (offload expensive work; isolate limits/platform notes): https://docs.flutter.dev/perf/isolates and https://docs.flutter.dev/cookbook/networking/background-parsing (HIGH)
- `workmanager` package docs (background scheduling support on Android/iOS): https://pub.dev/packages/workmanager (HIGH)
- `flutter_secure_storage` package docs (platform secure stores and configuration caveats): https://pub.dev/packages/flutter_secure_storage (HIGH)
- `media_kit` package docs (cross-platform playback and event streams): https://pub.dev/packages/media_kit (MEDIUM)
- Microsoft Graph delta query overview (incremental change tracking pattern): https://learn.microsoft.com/en-us/graph/delta-query-overview (HIGH)
- HTTP conditional request validators and preconditions (ETag/If-Match/If-None-Match): https://www.rfc-editor.org/rfc/rfc7232 (HIGH)
- WebDAV spec (locking/collision avoidance and conditional semantics): https://datatracker.ietf.org/doc/html/rfc4918 (MEDIUM)

---
*Architecture research for: cross-platform Flutter personal media app with offline-first + remote storage streaming*
*Researched: 2026-02-27*
