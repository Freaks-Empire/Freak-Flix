# Phase 02 Release Artifact Ledger

Generated: 2026-02-28T01:50:41Z
Command: `pwsh ./scripts/release/build_all_release.ps1 -NoPublish`

| Platform | Status | Command | Artifact | Exists | Warnings | Blockers | Log |
|---|---|---|---|---|---:|---:|---|
| Web | PASS | `flutter build web --release` | `D:\Code\Freak-Flix\build\web\index.html` | yes | 1 | 0 | `D:\Code\Freak-Flix\scripts\release\logs\web-build.log` |
| Windows | PASS | `flutter build windows --release` | `D:\Code\Freak-Flix\build\windows\x64\runner\Release\freakflix.exe` | yes | 0 | 0 | `D:\Code\Freak-Flix\scripts\release\logs\windows-build.log` |
| Android | PASS | `flutter build apk --release` | `D:\Code\Freak-Flix\build\app\outputs\flutter-apk\app-release.apk` | yes | 5 | 0 | `D:\Code\Freak-Flix\scripts\release\logs\android-build.log` |

## Classification

- Web: warning
- Windows: clean
- Android: warning

## Notes

- Preflight status: PASS/WARN
- Android build uses retry-safe clean strategy via `build_android_release.ps1`.
