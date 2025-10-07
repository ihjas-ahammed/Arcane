# arcane

A Flutter version of the Task Dominion application.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firebase Setup

This project uses Firebase. To configure it:
1. Make sure you have the FlutterFire CLI installed: `flutter`
2. Run `flutterfire configure` in the project root and select your Firebase project. This will generate `lib/firebase_options.dart`.

## API Keys

AI features require API keys. Create a file `lib/src/config/api_keys.dart` with your Gemini API keys:
```dart
// lib/src/config/api_keys.dart
// IMPORTANT: Add this file to your .gitignore
const List<String> GEMINI_API_KEYS = ['YOUR_GEMINI_API_KEY_1_HERE'];
const String GEMINI_MODEL_NAME = 'gemini-1.5-flash-latest'; // Or your preferred model
```
Ensure this file is added to your `.gitignore`.
