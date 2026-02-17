# Contributing to Freak-Flix

Thank you for your interest in contributing to Freak-Flix! This document provides guidelines for contributing to the project.

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.38.4 or later
- [Git](https://git-scm.com/)
- A code editor (VS Code, Android Studio, etc.)

### Setting Up Development Environment

1. **Fork the repository**
   ```bash
   git clone https://github.com/Freaks-Empire/Freak-Flix.git
   cd Freak-Flix
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Create your .env file**
   ```bash
   cp .env.example .env
   # Edit .env with your API keys
   ```

4. **Run the app**
   ```bash
   flutter run -d windows    # or -d android, -d chrome
   ```

## 📝 Code Style

We follow standard Flutter/Dart conventions:

- Use `dart format` before committing
- Run `flutter analyze` to check for issues
- Follow the existing code structure in `lib/`
- Use meaningful variable and function names

### File Organization
```
lib/
├── models/       # Data models
├── providers/    # State management
├── screens/      # UI screens
├── services/     # API integrations
├── widgets/      # Reusable components
└── utils/        # Utilities
```

## 🐛 Reporting Bugs

When reporting bugs, please include:

- **OS and version** (e.g., Windows 11, Android 13)
- **Flutter version** (run `flutter --version`)
- **Steps to reproduce**
- **Expected behavior**
- **Actual behavior**
- **Screenshots** (if applicable)
- **Error logs** (if any)

## 💡 Suggesting Features

Feature requests are welcome! Please:

1. Check if the feature has already been requested
2. Open a new issue with the `enhancement` label
3. Describe the feature and its use case
4. Explain why it would be useful

## 🔧 Pull Request Process

1. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/bug-description
   ```

2. **Make your changes**
   - Write clear, concise code
   - Add comments where necessary
   - Update documentation if needed

3. **Test your changes**
   ```bash
   flutter analyze
   flutter test
   ```

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add new feature"
   ```

   Follow conventional commit format:
   - `feat:` - New feature
   - `fix:` - Bug fix
   - `docs:` - Documentation changes
   - `style:` - Code style changes
   - `refactor:` - Code refactoring
   - `test:` - Adding tests
   - `chore:` - Maintenance tasks

5. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create a Pull Request**
   - Provide a clear description
   - Reference any related issues
   - Include screenshots for UI changes

## 🧪 Testing

- Write tests for new features
- Ensure existing tests pass
- Test on multiple platforms if possible

## 📚 Documentation

- Update README.md if you change functionality
- Add inline documentation for complex code
- Update this file if contribution processes change

## 🏷️ Issue Labels

We use labels to organize issues:

- `bug` - Something isn't working
- `enhancement` - New feature or request
- `documentation` - Improvements to docs
- `good first issue` - Good for newcomers
- `help wanted` - Extra attention needed
- `question` - Further information requested

## 💬 Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome newcomers
- Accept constructive criticism
- Focus on what's best for the community

### Unacceptable Behavior

- Trolling or insulting comments
- Public or private harassment
- Publishing others' private information
- Other unethical conduct

## 📞 Getting Help

- Check existing [Issues](https://github.com/Freaks-Empire/Freak-Flix/issues)
- Join discussions in existing issues
- Create a new issue with the `question` label

## 🙏 Thank You!

Every contribution helps make Freak-Flix better. We appreciate your time and effort!

---

**Happy coding!** 🎉
