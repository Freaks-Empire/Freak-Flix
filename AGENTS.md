# AGENTS.md

Guidelines for AI coding agents working in Freak-Flix repository.

## Project Overview

Freak-Flix is a Flutter media library app with multi-storage backend support (Local, OneDrive, SFTP, FTP, WebDAV). Uses Provider for state management, Go Router for navigation, and integrates with TMDB, AniList, and StashDB APIs.

**Tech Stack:** Flutter 3.38.4 (Dart 3.10.3), Provider, Go Router, Firebase, Media Kit, MSIX packaging

## Build/Run/Test Commands

```bash
# Install dependencies
flutter pub get

# Run locally
flutter run -d windows      # Windows (primary dev platform)
flutter run -d chrome       # Web
flutter run -d android      # Android

# Build release
flutter build windows --release
flutter build web --release
flutter build android --release

# MSIX package
flutter pub run msix:create

# Testing
flutter test                                    # Run all tests
flutter test test/security/command_injection_test.dart    # Single test file
flutter test --coverage                         # With coverage

# Linting & formatting
flutter analyze                                 # Static analysis
flutter format .                                # Format all files
dart format --set-exit-if-changed .            # CI check
```

## Code Style Guidelines

### Import Order
1. Dart core (`dart:*`)
2. Flutter (`package:flutter/*`)
3. Third-party packages
4. Local relative imports (`../models/`, `../providers/`)

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';

import '../models/media_item.dart';
import '../providers/library_provider.dart';
```

### Naming Conventions
- **Files:** `snake_case.dart` (e.g., `library_provider.dart`)
- **Classes:** `PascalCase` (e.g., `LibraryProvider`)
- **Variables/Methods:** `camelCase` (e.g., `mediaItems`, `fetchMetadata()`)
- **Constants:** `UPPER_SNAKE_CASE` (e.g., `_BASE_URL`)
- **Private members:** `_` prefix (e.g., `_client`, `_cache`)
- **Widgets:** Suffix with `Widget` if not obvious

### File Headers
Every file must start with a descriptive header:
```dart
/// lib/screens/library_screen.dart
/// 
/// Main library screen showing user's media collection

import 'package:flutter/material.dart';
```

### Class Structure
```dart
class ExampleProvider extends ChangeNotifier {
  List<MediaItem> _items = [];
  bool _isLoading = false;
  
  List<MediaItem> get items => _items;
  bool get isLoading => _isLoading;
  
  Future<void> loadItems() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _items = await service.fetchItems();
    } catch (e) {
      _handleError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void _handleError(dynamic error) {
    debugPrint('Error: $error');
  }
}
```

### Error Handling
Always use try-catch with context checking:
```dart
try {
  final result = await api.fetchData();
  return result;
} catch (e) {
  debugPrint('API error: $e');
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to load data')),
    );
  }
  return null;
}
```

### State Management
Provider with ChangeNotifier:
```dart
// In widgets
Consumer<LibraryProvider>(
  builder: (context, library, child) => ListView.builder(
    itemCount: library.items.length,
    itemBuilder: (context, index) => MediaCard(library.items[index]),
  ),
)
```

## Linting Configuration
Project uses `flutter_lints` with custom rules in `analysis_options.yaml`:
- `avoid_print: false` - print allowed for debugging
- `prefer_const_declarations: false` - flexible const usage

## Testing Guidelines

### Test Structure
```dart
/// test/security/command_injection_test.dart
/// 
/// Tests for command injection attack prevention
import 'package:flutter_test/flutter_test.dart';
import '../helpers/security_test_helpers.dart';

void main() {
  group('Command Injection Tests', () {
    test('blocks semicolon injection', () {
      SecurityTestHelpers.expectSecurityBlocked(
        'user; rm -rf /',
        (input) => InputValidation.validateUsername(input),
        customMessage: 'Semicolon injection should be blocked',
      );
    });
  });
}
```

Security tests are in `test/security/` - use `SecurityTestHelpers` for assertions.

## Architecture

### Directory Structure
```
lib/
├── main.dart              # App entry point
├── app.dart               # Root widget with MultiProvider
├── router.dart            # GoRouter configuration
├── models/                # Data models
├── providers/             # ChangeNotifier providers
├── screens/               # Full-screen widgets
├── services/              # API integrations
├── widgets/               # Reusable UI components
└── utils/                 # Utilities, input validation
```

### API Integration
- Pass `http.Client` for dependency injection
- Implement fromJson/toJson in models
- Store API keys in `.env` file
- Handle null safety explicitly

### Performance
- Use `const` constructors where possible
- Use `ListView.builder` for long lists
- Dispose resources properly
- Use `cached_network_image` for remote images

## Environment
- Use `.env` file for environment variables
- Load via `flutter_dotenv` package
- Never commit sensitive data
- Version in `pubspec.yaml` under `msix_config:`
