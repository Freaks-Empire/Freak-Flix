# AGENTS.md

This file contains guidelines and commands for agentic coding agents working in the Freak-Flix repository.

## Project Overview

Freak-Flix is a Flutter-based cross-platform media library application that helps users organize and stream their media content. The app uses Provider for state management, Go Router for navigation, and integrates with multiple media APIs.

**Tech Stack:**
- Flutter 3.38.4 (Dart 3.10.3)
- Provider state management
- Go Router for navigation
- MSIX packaging for Windows
- Firebase for cloud sync

## Development Commands

### Package Management
```bash
# Install dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade
```

### Running the Application
```bash
# Run on Windows (primary development platform)
flutter run -d windows

# Run on Android
flutter run -d android

# Run on Web (Chrome)
flutter run -d chrome

# Run with specific build flavor
flutter run --release
```

### Building for Release
```bash
# Windows release build
flutter build windows --release

# Android release build
flutter build android --release

# Web release build
flutter build web --release

# Create MSIX package (Windows distribution)
flutter pub run msix:create

# Use the automated Windows release script
.\build_release.ps1
```

### Testing Commands
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage

# Run tests in watch mode
flutter test --watch
```

### Code Quality
```bash
# Static analysis (linting)
flutter analyze

# Format code
dart format .

# Check for formatting issues
dart format --set-exit-if-changed .
```

## Code Style Guidelines

### File Organization
```
lib/
├── main.dart                 # App entry point
├── app.dart                  # Root app widget
├── router.dart               # Route configuration
├── models/                   # Data models and entities
├── providers/                # State management (Provider pattern)
├── screens/                  # Full-screen UI components
├── services/                 # API integrations and external services
├── widgets/                  # Reusable UI components
└── utils/                    # Utility functions and helpers
```

### Naming Conventions
- **Files**: `snake_case.dart` (e.g., `media_item.dart`, `library_provider.dart`)
- **Classes**: `PascalCase` (e.g., `MediaItem`, `LibraryProvider`)
- **Variables/Methods**: `camelCase` (e.g., `mediaItems`, `fetchMetadata()`)
- **Constants**: `UPPER_SNAKE_CASE` (e.g., `_baseHost`, `_imageBase`)
- **Private members**: Prefix with `_` (e.g., `_client`, `_filter`)

### Import Style
```dart
// Dart core imports first
import 'dart:convert';
import 'dart:async';

// Flutter packages
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Third-party packages
import 'package:http/http.dart' as http;

// Local imports (relative)
import '../models/media_item.dart';
import '../providers/library_provider.dart';
```

### Class and Widget Structure
```dart
/// File header describing the purpose of this widget/service
/// lib/widgets/example_widget.dart
import 'package:flutter/material.dart';

/// A brief description of what this widget does.
/// Use dartdoc comments for all public APIs.
class ExampleWidget extends StatelessWidget {
  const ExampleWidget({super.key});
  
  @override
  Widget build(BuildContext context) {
    // Implementation
  }
}
```

### State Management Pattern
Use Provider pattern consistently:
```dart
// In widgets
Consumer<LibraryProvider>(
  builder: (context, library, child) {
    final bool isLoading = library.isLoading;
    // UI implementation
  },
)

// In models/services
class LibraryProvider extends ChangeNotifier {
  List<MediaItem> _items = [];
  List<MediaItem> get items => _items;
  
  Future<void> fetchItems() async {
    // Implementation
    notifyListeners();
  }
}
```

### Error Handling
- Use try-catch blocks for all async operations
- Provide user-friendly error messages
- Log errors appropriately (avoid print in production)
- Handle null values with proper null safety

```dart
try {
  final result = await apiCall();
  return result;
} catch (e) {
  debugPrint('Error fetching data: $e');
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to load data')),
    );
  }
  return null;
}
```

### API Integration Guidelines
- Use dependency injection for services (pass http.Client)
- Implement proper error handling and null safety
- Use cached_network_image for remote images
- Follow existing service patterns (like TmdbService)
- Store API keys in environment variables (.env file)

### Testing Strategy
- **Widget tests**: For UI components in `test/` directory
- **Unit tests**: For services and providers
- **Integration tests**: For critical user flows
- Use `flutter_test` package with proper test structure

```dart
// Example test structure
void main() {
  testWidgets('MediaItemCard displays correctly', (WidgetTester tester) async {
    // Test implementation
  });
}
```

## Architecture Guidelines

### Provider Usage
- Create separate providers for different domains (Library, Settings, Player)
- Use ChangeNotifier for state management
- Call `notifyListeners()` after state changes
- Access providers through Consumer or Provider.of

### Navigation
- Use Go Router for all navigation
- Define routes in `lib/router.dart`
- Use named routes with proper path parameters
- Handle deep linking appropriately

### Data Models
- Keep models in `lib/models/` with proper JSON serialization
- Use fromJson/toJson methods for API integration
- Implement proper equality operators
- Use immutable objects where possible

### Services
- Keep services in `lib/services/` for API integrations
- Use dependency injection (pass http.Client)
- Implement proper error handling
- Cache responses when appropriate

## Build and Deployment

### Version Management
- Version is managed in `pubspec.yaml`
- Use git commit count for automated versioning
- Maintain consistency across all platforms

### Windows Distribution
- Use MSIX packaging for Windows Store distribution
- Configure MSIX settings in `pubspec.yaml`
- Test MSIX package before distribution

### Environment Configuration
- Use `.env` file for environment variables
- Load with `flutter_dotenv` package
- Never commit sensitive data to repository

## Common Patterns

### Async Operations
```dart
Future<void> loadData() async {
  if (isLoading) return;
  
  _isLoading = true;
  notifyListeners();
  
  try {
    _items = await service.fetchItems();
  } catch (e) {
    _error = e.toString();
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}
```

### Responsive Design
- Use LayoutBuilder for responsive layouts
- Consider different screen sizes
- Test on multiple platforms

### Performance
- Use `const` constructors where possible
- Implement proper image caching
- Use ListView.builder for long lists
- Dispose resources properly

## Linting and Analysis

The project uses `flutter_lints` with some custom rules:
- `avoid_print: false` (allowed for debugging)
- `prefer_const_declarations: false` (flexible const usage)

Always run `flutter analyze` before committing changes to ensure code quality.