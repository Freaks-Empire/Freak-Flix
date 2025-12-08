# Freak-Flix
Netsflix But Open Source

## Freak-Flix (Flutter) Setup
- flutter pub get
- flutter run -d linux|macos|windows|android
- Configure Trakt Client ID in `lib/services/trakt_service.dart` (`_traktClientId`)
- AniList uses the public endpoint; adjust the query in `lib/services/anilist_service.dart`
- Add new metadata providers via `lib/services/metadata_service.dart`
- MPV playback via `flutter_mpv`: on Windows place `mpv-1.dll` next to the built exe; on Linux install `libmpv-dev` (e.g., `sudo apt install libmpv-dev`).
