# Changelog

All notable changes to Freak-Flix will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-06-22

### Added
- Device Code Flow authentication for web OneDrive integration
- User panel screen with profile management
- Android APK releases to GitHub releases
- Windows ZIP package releases
- CI pipeline improvements: test steps for all platform builds

### Changed
- Web authentication now uses Device Code Flow instead of popup OAuth
- Updated release workflow to include all platforms
- MSIX packaging config updated for v1.2.0

### Fixed
- Fixed AADSTS9002327 CORS error for web OneDrive authentication
- Fixed AADSTS50011 redirect URI mismatch error
- Fixed release workflow to upload ZIP files alongside EXE

### Security
- Android ProGuard rules enabled for release builds

## [1.1.0] - 2025-02-17

### Added
- Multi-storage backend support (SFTP, FTP, WebDAV)
- Remote folder picker for cloud storage
- Device code authentication flow for all platforms
- Security test suite (command injection, directory traversal, SSRF)
- Auto-backup manager for OneDrive

### Changed
- Switched from popup OAuth to Device Code Flow for better cross-platform support
- Improved error handling for cloud storage connections

### Fixed
- OneDrive authentication issues on web platform
- Build workflow improvements

## [1.0.0] - 2025-01-15

### Added
- Initial release of Freak-Flix
- Windows desktop application
- Android mobile application
- Web application (PWA)
- TMDB integration for movies and TV shows
- AniList integration for anime
- StashDB integration for adult content
- OneDrive cloud streaming
- Media Kit video player
- Library organization by type (Movies, TV, Anime, Adult)
- Actor profiles and filmography
- Resume playback functionality
- Cross-platform sync via OneDrive

### Features
- Netflix-style UI
- Automatic metadata fetching
- Cloud storage support (OneDrive)
- Privacy-focused design
- No server required

---

## Release Notes Format

Each release includes:

### Added
- New features

### Changed
- Changes to existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Removed features

### Fixed
- Bug fixes

### Security
- Security improvements

---

## Version Numbering

We use [Semantic Versioning](https://semver.org/):

- **MAJOR** version - Incompatible API changes
- **MINOR** version - Added functionality (backwards compatible)
- **PATCH** version - Bug fixes (backwards compatible)

Example: `1.2.3` = Major 1, Minor 2, Patch 3
