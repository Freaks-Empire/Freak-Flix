# SPEC.md — Project Specification

> **Status**: `FINALIZED`

## Vision
Decompose Freak-Flix's monolithic god classes into a clean, modular architecture. The 2,346-line `LibraryProvider`, the 81KB `settings_library_section` widget, and three 30+ KB duplicate detail screens will be broken into focused, single-responsibility components. The state management layer will be re-evaluated and potentially migrated from `provider` to a more scalable solution. The result is a codebase that's maintainable, testable, and easy to extend.

## Goals
1. **Decompose `LibraryProvider`** — Extract scanning, filtering, metadata orchestration, notifications, import/export, and remote storage into dedicated services, leaving a thin coordinator provider
2. **Decompose `settings_library_section.dart`** — Split the 81KB monolith into focused sub-widgets per concern (folder management, scanning, remote connections, etc.)
3. **Deduplicate detail screens** — Extract shared layout patterns from `MovieDetailsScreen`, `AnimeDetailsScreen`, and `SceneDetailsScreen` into reusable base components
4. **Re-architect state management** — Evaluate and migrate from `provider` to a more scalable pattern (e.g., Riverpod) across the application
5. **Establish test coverage** — Add unit tests for extracted services and widget tests for decomposed UI components

## Non-Goals (Out of Scope)
- New features or integrations
- UI redesign or visual changes
- API contract changes
- Database/persistence layer rewrite
- Platform-specific native code changes

## Users
The primary user is the maintainer (you) — this refactor makes the codebase easier to reason about, debug, test, and extend with new features in future phases.

## Constraints
- **Zero behavior change** — The app must function identically after refactoring
- **Incremental delivery** — Each phase must leave the app in a buildable, runnable state
- **Flutter SDK ≥3.4.0** — Current minimum stays
- **No timeline pressure** — Quality over speed

## Success Criteria
- [ ] `LibraryProvider` reduced to <300 lines (coordinator only)
- [ ] No source file exceeds 500 lines / 15KB
- [ ] Detail screens share a base component for common layout
- [ ] State management migrated to chosen solution
- [ ] All extracted services have unit tests
- [ ] App builds and runs identically on all platforms (Web, Windows, Android minimum)
- [ ] `flutter analyze` passes with no new warnings
