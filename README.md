# 🎯 Focus Quest

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-blue?style=for-the-badge)

**A dopamine-driven productivity planner designed for users with ADHD**

[Features](#-key-features) • [Installation](#-installation) • [Documentation](#-documentation) • [Contributing](CONTRIBUTING.md)

</div>

---

## 📝 About

Focus Quest is a **dopamine-driven productivity planner** designed specifically for users with ADHD. It focuses on overcoming executive dysfunction, time blindness, and task initiation paralysis through gamification and low-friction interactions.

### 🎯 Core Principles

- **Anti-Shame Design**: No guilt trips, just progress
- **Low Friction**: Create tasks in seconds, not minutes
- **Gamification**: Earn XP, level up, unlock achievements
- **Dopamine Optimization**: Visual feedback, streaks, and instant gratification
- **Local-First**: Your data stays on your device

## ✨ Key Features

- **Quest Management:** Anti-shame, low-friction task creation with categories and energy levels
- **Sub-Quests:** 5-minute micro-tasks to combat overwhelm
- **Focus Mode:** Pomodoro-style timer with pause/resume and session tracking
- **Progress System:** XP, leveling, streaks, and achievements
- **Personalized Experience:** Dynamic time-based greetings and user display name
- **Theme Support:** Light/Dark mode with persistent preference
- **Local-First:** Pure Sembast (offline-first) reliability
- **Multi-Platform:** Built with Flutter for Android, iOS, macOS, Linux, Windows, and Web

📖 **[See detailed feature list →](FEATURES.md)**

## 📐 Design & Architecture

The project follows a local-first architecture where the local database (Sembast) is the single source of truth.

For a detailed breakdown of the system architecture, module breakdown, and technical stack, please refer to:

- [**Features Overview**](FEATURES.md)
- [**High-Level Design (HLD) Plan**](hld.md)
- [**Theme System Documentation**](lib/core/theme/theme.md)

## 📁 Folder Structure

```
lib/
├── core/
│   ├── theme/
│   ├── constants/
│   ├── utils/
│   └── widgets/
├── features/
│   ├── auth/         # Login, Sign up, Auth State
│   ├── tasks/        # Quests, SubQuests, Brain Dump
│   ├── journal/      # Daily Reflection, Mood
│   ├── timer/        # Focus Mode, Pomodoro, Session Tracking
│   ├── profile/      # XP, Level, Stats, Heatmap
│   └── settings/     # Sync Controller, Theme Toggle
├── l10n/             # Localization ARB files
├── models/           # Quest, FocusSession, JournalEntry, UserProgress
├── providers/        # State Management
└── services/         # Sembast, Firestore, Notifications, Audio/Haptics
```

---

## 🚀 Installation

### Prerequisites

- **Flutter SDK** (3.0 or higher)
- **Dart SDK** (3.0 or higher)
- Platform-specific requirements:
  - **Android**: Android Studio, SDK 21+
  - **iOS**: Xcode 13+, macOS
  - **Web**: Chrome (for development)
  - **Desktop**: Platform-specific toolchains

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/focus_quest.git
   cd focus_quest
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate localization files**
   ```bash
   flutter gen-l10n
   ```

4. **Run the app**
   ```bash
   # For development on your default device
   flutter run

   # For specific platforms
   flutter run -d chrome          # Web
   flutter run -d macos           # macOS
   flutter run -d android         # Android
   flutter run -d ios             # iOS
   ```

### Building for Production

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# macOS
flutter build macos --release

# Web
flutter build web --release

# Windows
flutter build windows --release

# Linux
flutter build linux --release
```

---

## 📖 Documentation

- **[Features Overview](FEATURES.md)** - Detailed feature breakdown
- **[High-Level Design (HLD)](hld.md)** - System architecture and technical stack
- **[Theme System](lib/core/theme/theme.md)** - Theming implementation guide
- **[Contributing Guidelines](CONTRIBUTING.md)** - How to contribute
- **[Firebase Configuration](FIREBASE_CONFIG.md)** - Firebase setup (optional)

---

## 🌍 Internationalization (i18n)

This project uses Flutter's official localization system with ARB (Application Resource Bundle) files.

### Initial Setup (Already Completed)

The following setup has been completed for this project:

#### 1. Dependencies Added to `pubspec.yaml`

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.20.2
```

#### 2. Enable Code Generation in `pubspec.yaml`

```yaml
flutter:
  generate: true
```

#### 3. Configuration File `l10n.yaml`

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

#### 4. MaterialApp Configuration in `main.dart`

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:focus_quest/l10n/app_localizations.dart';

MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [
    Locale('en'),
    Locale('es'),
  ],
  // ...
)
```

---

### Adding New Translations

Follow these steps to add new translatable strings:

#### Step 1: Add the String to English ARB (Template)

Edit `lib/l10n/app_en.arb`:

```json
{
  "@@locale": "en",
  "appTitle": "FocusQuest",
  "@appTitle": {
    "description": "The application title"
  },
  "welcomeMessage": "Welcome to FocusQuest!",
  "@welcomeMessage": {
    "description": "Welcome message shown on the home screen"
  }
}
```

> **Note:** The `@<key>` entries are metadata (description, placeholders) and are only needed in the template file (`app_en.arb`).

#### Step 2: Add Translations to Other Locales

Edit `lib/l10n/app_es.arb`:

```json
{
  "@@locale": "es",
  "appTitle": "FocusQuest",
  "welcomeMessage": "¡Bienvenido a FocusQuest!"
}
```

#### Step 3: Generate Localization Code

Run Flutter build or generate command:

```bash
flutter gen-l10n
```

Or simply run your app — Flutter auto-generates on build:

```bash
flutter run
```

The generated files will appear in `lib/l10n/`:

- `app_localizations.dart`
- `app_localizations_en.dart`
- `app_localizations_es.dart`

#### Step 4: Use the Localized String in Code

```dart
import 'package:focus_quest/l10n/app_localizations.dart';

// In your widget:
Text(AppLocalizations.of(context)!.welcomeMessage)
```

---

### Using Placeholders in Translations

For dynamic values, use placeholders:

#### ARB File (`app_en.arb`)

```json
{
  "questsCompleted": "You completed {count} quests today!",
  "@questsCompleted": {
    "description": "Message showing number of completed quests",
    "placeholders": {
      "count": {
        "type": "int",
        "example": "5"
      }
    }
  }
}
```

#### Spanish Translation (`app_es.arb`)

```json
{
  "questsCompleted": "¡Completaste {count} misiones hoy!"
}
```

#### Usage in Code

```dart
Text(AppLocalizations.of(context)!.questsCompleted(5))
```

---

### Adding a New Language

#### Step 1: Create a New ARB File

Create `lib/l10n/app_<locale>.arb` (e.g., `app_fr.arb` for French):

```json
{
  "@@locale": "fr",
  "appTitle": "FocusQuest",
  "welcomeMessage": "Bienvenue sur FocusQuest!"
}
```

#### Step 2: Add the Locale to `supportedLocales`

Update `main.dart`:

```dart
supportedLocales: const [
  Locale('en'),
  Locale('es'),
  Locale('fr'),  // Add new locale
],
```

#### Step 3: Regenerate Localization Files

```bash
flutter gen-l10n
```

---

### Pluralization

For plural forms, use the ICU message format:

#### ARB File

```json
{
  "itemCount": "{count, plural, =0{No items} =1{1 item} other{{count} items}}",
  "@itemCount": {
    "description": "Shows the number of items",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
}
```

#### Usage

```dart
Text(AppLocalizations.of(context)!.itemCount(items.length))
```

---

### Best Practices

1. **Always add descriptions** to your template ARB file (`app_en.arb`) — they help translators understand context.

2. **Use meaningful keys** — prefer `welcomeMessage` over `msg1`.

3. **Keep translations in sync** — when adding a key to `app_en.arb`, add it to all other locale files.

4. **Test all locales** — verify translations display correctly, especially for longer text that might overflow UI elements.

5. **Use placeholders for dynamic content** — never concatenate translated strings.

---

## Getting Started

This project is a starting point for a Flutter application.

For help getting started with Flutter development, view the [online documentation](https://docs.flutter.dev/).
