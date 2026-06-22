# Release Notes

## v1.2.0 — 2026-06-22

### Highlights
- User panel screen with profile management
- Device Code Flow authentication for web OneDrive integration
- Platform release polish for Android, Web/PWA, and Windows
- CI pipeline with automated testing on all platforms

### Downloads

| Platform | Download |
|----------|----------|
| **Android** | `freakflix-android-{build_number}.apk` |
| **Windows** | `freakflix-windows-{build_number}.zip` (portable)<br>`freakflix-{build_number}.exe` (standalone) |
| **Web (PWA)** | Deployed via Netlify — visit [freak-flix.netlify.app](https://freak-flix.netlify.app) |
| **MSIX** | `FreakFlix_1.2.0.0.msix` (sideload via AppInstaller) |

### What's New

#### User Panel
- New user panel screen for profile management
- Navigation and integration logic improvements

#### Authentication
- Device Code Flow for web OneDrive — no more CORS errors
- Fixed AADSTS9002327 and AADSTS50011 errors

#### Platform Improvements
- **Android**: Release APK builds via CI, ProGuard enabled for security
- **Web**: PWA with standalone display, service worker, offline support
- **Windows**: MSIX packaging, AppInstaller for auto-updates

#### CI/CD
- Test steps added to all platform build workflows
- Flutter analyze and formatting checks on Windows builds
- Automated GitHub Releases for APK and ZIP artifacts

### Android
- **APK**: Built with `flutter build apk --release`
- **Security**: Code shrinking and resource shrinking enabled
- **Note**: Requires release keystore for Play Store submission

### Windows
- **MSIX**: Sideload-ready package at `docs/FreakFlix_1.2.0.0.msix`
- **AppInstaller**: Auto-update via `docs/FreakFlix.appinstaller`
- **Portable**: Full ZIP package with all dependencies
- **Standalone**: Single EXE (requires VC++ Redistributables)

### Web (PWA)
- Hosted on Netlify with automatic deployments
- OAuth callback support via Netlify Functions
- Client-side routing via redirect rules
- PWA manifest with 192px and 512px icons

### Upgrading

- **Android**: Download latest APK from GitHub Releases
- **Windows**: AppInstaller checks for updates on launch, or download manually
- **Web**: Refresh browser — updates are served automatically

### Known Issues
- Android release signing requires manual keystore setup
- MSIX Store submission not yet configured (`store: false`)

---

## Template for Future Releases

### Highlights
- {Major feature or change}

### Downloads
| Platform | Link |
|----------|------|
| Android | download link |
| Windows | download link |
| Web | deployment link |

### What's New
- {Feature 1}
- {Feature 2}

### Upgrading
- {Upgrade instructions}

### Known Issues
- {Issue 1}
