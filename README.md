# Task Dominion: Arcane Edition

## What is this?
Task Dominion is a highly gamified, tactical life-management and productivity tracker. Designed with aesthetics inspired by competitive agents and cinematic universes (Valorant, Arcane, Spider-Man, Jurassic World Evolution), it transforms daily chores, long-term goals, and financial tracking into "Missions," "Protocols," and "Objectives."

## Why?
Productivity apps often feel like a chore. Task Dominion bridges the gap between gaming and real life by introducing XP, levels, and system diagnostics (Well-being traits like Resilience, Autonomy, Vitality). By treating life as a series of tactical operations, complete with post-action debriefs and analytics, it makes self-improvement engaging and structured.

## Leveling System (Wellbeing Momentum)
The agent's leveling system is entirely dynamic, designed to reflect recent momentum rather than permanent accumulation. 
*   **Rolling Window**: Level and XP are calculated *strictly* from the XP gained over the last 7 days. If you stop logging, your levels will naturally decay, promoting consistent reflection.
*   **Exponential Limit**: The XP required to level up increases slightly exponentially each level to provide a balanced challenge.
*   **Equation**: `MaxXP(Level) = round(100 * (1.15 ^ (Level - 1)))`

## How it works
The system is built on a robust Flutter frontend powered by **Firebase** and **Google Gemini AI**.
* **Primary Sync**: Uses Firebase Realtime Database for ultra-fast, seamless state synchronization.
* **Failsafe Storage**: Uses Cloud Firestore as a secondary snapshot backup layer, preventing data loss.
* **Neural Engine**: Integrates Gemini AI to process journal logs, automatically extract assets/allies, simulate future situations, and provide "Nora" chatbot therapy.
* **Behavioral Overrides**: Includes an Atomic Habits framework tool to manage dopamine and screen-time.

---

## Developer Setup

### 1. Prerequisites
Ensure you have the Flutter SDK installed.
* Run `flutter doctor` to verify your environment.
* Install project dependencies: `flutter pub get`

### 2. Firebase Configuration
This project relies heavily on Firebase. 
1. Ensure you have the FlutterFire CLI installed: `npm install -g firebase-tools` then `dart pub global activate flutterfire_cli`.
2. Run `flutterfire configure` in the project root and link it to your Firebase project.

### 3. Enable Realtime Database (Primary Data Layer)
Realtime Database is used for live state syncing.
1. Open the Firebase Console.
2. Navigate to **Build > Realtime Database** and click **Create Database**.
3. Choose a location and start in **Locked mode**.
4. Update the Rules to allow authenticated user access to their own nodes:
```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    }
  }
}
```

### 4. Enable Cloud Firestore (Backup & Archival Layer)
Firestore is used for manual snapshots and archived weekly reports.
1. Navigate to **Build > Firestore Database** and click **Create Database**.
2. Update the Security Rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 5. API Keys Configuration
AI features require Gemini API keys.
1. Create a file `lib/src/config/api_keys.dart`.
2. Add your Gemini API keys:
```dart
// lib/src/config/api_keys.dart
// IMPORTANT: Add this file to your .gitignore
const List<String> geminiApiKeys = ['YOUR_GEMINI_API_KEY_1_HERE'];
const String geminiModelName = 'gemini-2.0-flash'; 
```
*Note: Make sure this file is added to your `.gitignore` to prevent exposing your keys.*