# 🎬 Freak-Flix - Cross-Platform Media Library Manager

[![Flutter](https://img.shields.io/badge/Flutter-3.38.4-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10.3-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android%20%7C%20Web-blue?style=for-the-badge)](https://flutter.dev)
[![Build Status](https://github.com/Freaks-Empire/Freak-Flix/actions/workflows/flutter-windows.yml/badge.svg)](https://github.com/Freaks-Empire/Freak-Flix/actions)
[![License](https://img.shields.io/badge/License-Custom-green?style=for-the-badge)](LICENSE)
[![Downloads](https://img.shields.io/github/downloads/Freaks-Empire/Freak-Flix/total?style=for-the-badge)](https://github.com/Freaks-Empire/Freak-Flix/releases)

> **A Netflix-style media library for your local and cloud content.** Built with Flutter, Freak-Flix automatically organizes your movies, TV shows, and anime with rich metadata from TMDB, AniList, and StashDB.

<p align="center">
  <a href="#download">Download</a> •
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#screenshots">Screenshots</a> •
  <a href="#contributing">Contributing</a>
</p>

---

## 🎯 What is Freak-Flix?

**Freak-Flix** is a powerful, cross-platform media library manager that transforms your video collection into a beautiful, Netflix-like interface. Unlike Plex or Jellyfin, it works offline and supports multiple cloud storage backends without requiring a server.

### Perfect for:
- 🎬 **Movie collectors** who want automatic poster and metadata fetching
- 📺 **TV show enthusiasts** who need episode tracking and organization  
- 🍿 **Anime fans** with AniList integration for accurate metadata
- 🔒 **Privacy-conscious users** who prefer local/cloud storage over streaming services
- ☁️ **Multi-device users** who want to stream from OneDrive or other cloud providers

---

## 📥 Download <a name="download"></a>

Get the latest release for your platform:

| Platform | Download | Requirements |
|----------|----------|--------------|
| **Windows** | [freakflix.exe](https://github.com/Freaks-Empire/Freak-Flix/releases/latest) | Windows 10/11 |
| **Windows (Portable)** | [freakflix-windows.zip](https://github.com/Freaks-Empire/Freak-Flix/releases/latest) | Windows 10/11 |
| **Android** | [freakflix.apk](https://github.com/Freaks-Empire/Freak-Flix/releases/latest) | Android 8.0+ |
| **Web** | [freak-flix.protik.eu.org](https://freak-flix.protik.eu.org) | Modern browser |

📦 **All releases**: [View on GitHub](https://github.com/Freaks-Empire/Freak-Flix/releases)

---

## ✨ Features <a name="features"></a>

### 📚 Smart Library Organization
- **Automatic categorization**: Movies, TV Shows, Anime, and Adult content
- **Multi-library support**: Organize content by type and source
- **Cloud integration**: Add folders from OneDrive, SFTP, FTP, and WebDAV
- **Smart scanning**: Auto-detects file naming patterns and extracts metadata

### 🧠 Rich Metadata Fetching
- **Movies & TV Shows**: [TMDB (The Movie Database)](https://www.themoviedb.org/) integration
- **Anime**: [AniList](https://anilist.co/) for accurate anime metadata
- **Adult Content**: [StashDB](https://stashdb.org/) support with advanced tagging
- **Actor profiles**: Detailed bios and filmography

### ☁️ Cloud Storage Support
Stream directly without downloading:
- **OneDrive**: Microsoft OneDrive integration
- **SFTP**: Secure FTP over SSH
- **FTP**: Standard FTP connections
- **WebDAV**: Web-based distributed authoring

### 🎬 Premium Media Player
- **Media Kit**: High-performance video playback
- **Cross-platform**: Consistent experience on all platforms
- **Resume playback**: Continue watching from where you left off
- **Progress tracking**: Visual indicators for watched content

### 🔒 Privacy & Security
- **100% offline capable**: Works without internet after initial setup
- **Optional adult content**: Hidden UI toggles for sensitive content
- **No server required**: Direct connection to your storage
- **Secure authentication**: OAuth 2.0 for cloud services

---

## 🚀 Installation <a name="installation"></a>

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.38.4+ (for building from source)
- [TMDB API Key](https://www.themoviedb.org/documentation/api) (free registration)

### Option 1: Download Pre-built Binaries
1. Download the latest release from the [releases page](https://github.com/Freaks-Empire/Freak-Flix/releases)
2. Run the installer or extract the ZIP file
3. Launch Freak-Flix and configure your API keys

### Option 2: Build from Source

```bash
git clone https://github.com/Freaks-Empire/Freak-Flix.git
cd Freak-Flix
flutter pub get

# Run on your platform
flutter run -d windows    # Windows
flutter run -d android    # Android
flutter run -d chrome     # Web
```

---

## ⚙️ Configuration

### 1. TMDB API Setup (Required)
1. Create a free account at [TMDB](https://www.themoviedb.org/)
2. Go to Settings → API → Request API Key
3. Copy your API key into Freak-Flix Settings

### 2. OneDrive Integration (Optional)
1. Click "Connect OneDrive" in the app
2. Enter the displayed code at [microsoft.com/device](https://microsoft.com/device)

### 3. StashDB for Adult Content (Optional)
1. Register at [StashDB](https://stashdb.org/)
2. Enable "Adult Content" in Freak-Flix settings
3. Enter your StashDB API key

---

## 📸 Screenshots <a name="screenshots"></a>

<p align="center">
  <i>Screenshots coming soon! Check back for updates.</i>
</p>

---

## 📂 File Naming & Organization

### 🎬 Movies
```
Movies/
├── Inception (2010)/
│   └── Inception.2010.1080p.mkv
├── The Dark Knight (2008).mp4
└── Avatar.2009.mkv
```
**Best Practice**: `Title (Year).ext`

### 📺 TV Shows & Anime
```
TV Shows/
├── Breaking Bad/
│   ├── Season 1/
│   │   ├── Breaking Bad S01E01.mkv
│   │   └── Breaking Bad S01E02.mkv
└── Arcane/
    └── Arcane S01E01.mp4
```
**Required**: `SxxExx` pattern in filename

### 🔞 Adult Content
```
Adult/
├── Studio Name/
│   └── Scene Title (2023).mp4
└── Performer Name/
    └── Scene Title.mp4
```
Enable "Adult Content" in settings first.

---

## 📁 Project Structure

| Directory | Description |
| :--- | :--- |
| `lib/models` | Core data models (MediaItem, TmdbItem, CastMember) |
| `lib/providers` | State management (Library, Playback, Settings) |
| `lib/screens` | UI views (Home, Details, Player, Actor Profile) |
| `lib/services` | API Integrations (TMDB, AniList, StashDB, OneDrive) |
| `lib/widgets` | Reusable UI components |

---

## 🤝 Contributing <a name="contributing"></a>

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details.

---

## 📄 License

This project is open source and available for personal use and modification. See [LICENSE](LICENSE) for details.

---

## 🔗 Related Projects

- [Plex](https://www.plex.tv/) - Media server platform
- [Jellyfin](https://jellyfin.org/) - Open source media server
- [Emby](https://emby.media/) - Media server solution
- [Stash](https://github.com/stashapp/stash) - Adult content organizer

---

## 🏷️ Keywords

media library, video player, flutter app, movie organizer, tv show tracker, anime library, self-hosted media, plex alternative, jellyfin alternative, emby alternative, onedrive streaming, cloud media player, local media server, metadata fetcher, tmdb client, anilist client, stashdb client, cross platform media player, windows media player, android video player, web media player, offline media library
