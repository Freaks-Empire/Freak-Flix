# 🎬 Freak-Flix
**Netflix-style Media Player for Your Local & Cloud Content**

[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Android%20%7C%20Web-blue?style=for-the-badge)](https://flutter.dev)
[![Build Status](https://github.com/MNDL-27/Freak-Flix/actions/workflows/flutter-windows.yml/badge.svg)](https://github.com/MNDL-27/Freak-Flix/actions/workflows/flutter-windows.yml)
[![License](https://img.shields.io/badge/License-Open%20Source-green?style=for-the-badge)]()

Freak-Flix organizes your video library into a stunning, immersive interface. Whether it's your local collection or cloud favorites, experience them with rich metadata and a premium UI.

---

## ✨ Features

*   **📚 Library Organization**: Automatically scans and categorizes Movies, TV Shows, Anime, and Adult content.
*   **🧠 Rich Metadata**:
    *   **Movies & TV**: Integrated with [TMDB](https://www.themoviedb.org/).
    *   **Anime**: Powered by [AniList](https://anilist.co/).
    *   **Adult**: Enhanced with [StashDB](https://stashdb.org/).
*   **👥 Actor Profiles**: Explore detailed actor profiles, biographies, and randomized "Known For" lists.
*   **🏷️ Smart Tagging**: Imports StashDB tags as genres for superior organization.
*   **☁️ Cloud Streaming**: Stream directly from OneDrive without syncing files locally.
*   **🔒 Privacy First**: Optional, fast segregation of Adult content with hidden UI toggles.
*   **📱 Cross-Platform**: Optimized for Desktop (Windows), Mobile (Android), and Web.

---

## 🚀 Getting Started

### Prerequisites
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (Latest)
*   [TMDB API Key](https://www.themoviedb.org/documentation/api) (Free)

### 💻 Installation

#### 1. Clone & Install
```bash
git clone https://github.com/your-username/freak-flix.git
cd freak-flix
flutter pub get
```

#### 2. Run the App
**Windows**  
Ensure `mpv-1.dll` is available in your build directory (required for `media_kit`).
```bash
flutter run -d windows
```

**Android**
```bash
flutter run -d android
```

**Web**
```bash
flutter run -d chrome
```

---

## ⚙️ Configuration

1.  **Launch Freak-Flix** and typically head to **Settings**.
2.  **API Keys**: Enter your TMDB API Key to unlock metadata fetching.
3.  **Library**: Add your local folders. The app will auto-scan and populate your library.
4.  **(Optional) StashDB**:
    *   Go to *Settings > Advanced*
    *   Enable "Adult Content"
    *   Enter your StashDB Endpoint & API Key for pro-level adult metadata.

5.  **(Optional) OneDrive (Developer Setup)**:
    If you want to build the app yourself and use OneDrive, you need an Azure App ID.
    *   **Register an App**: Go to [Azure Portal](https://portal.azure.com/#blade/Microsoft_AAD_RegisteredApps/ApplicationsListBlade).
    *   **Platform**: Select "Mobile and desktop applications".
    *   **Permissions**: Add `User.Read`, `Files.Read`, `offline_access`.
    *   **Tenant**: Support "Accounts in any organizational directory (Any Azure AD directory - Multitenant) and personal Microsoft accounts".
    *   **Env Variables**:
        *   Create a `.env` file at the root.
        *   Add `GRAPH_CLIENT_ID=your_client_id`.
        *   Add `GRAPH_TENANT_ID=common` (usually 'common').

---

## 📂 File Naming & Organization

Freak-Flix detects content based on folder structure and filenames. Use these conventions for best results:

### 🎬 Movies
Place movies in your **Movies** library folder.
```text
Movies/
├── Inception (2010)/
│   └── Inception.2010.1080p.mkv
├── The Dark Knight.mp4
└── Avatar.2009.mkv
```
*   **Best Practice**: `Title (Year).ext` or `Title.Year.ext`.
*   The scanner extracts the Title and Year to find the correct poster and details.

### 📺 TV Shows & Anime
Place shows in your **TV** or **Anime** library folders.
```text
TV Shows/
├── Breaking Bad/
│   ├── Season 1/
│   │   ├── Breaking Bad S01E01.mkv
│   │   └── Breaking Bad S01E02.mkv
│   └── Season 2/
└── Arcane/
    └── Arcane S01E01.mp4
```
*   **Required**: `SxxExx` pattern (e.g., `S01E01`) in the filename.
*   **Alternative**: `Ep 01` or `- 01` (often used for Anime).
*   Files in the same folder are grouped together as a series.

### 🔞 Adult Content
Place adult scenes in your **Adult** library folder (if enabled).
```text
Adult/
├── Studio Name/
│   └── Scene Title (2023).mp4
└── Performer Name/
    └── Scene Title.mp4
```
*   **StashDB**: Scans based on the exact scene title or filename hash.
*   Enable **Adult Content** in settings to see this section.

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

## 📄 License
This project is open source and available for personal use and modification.
