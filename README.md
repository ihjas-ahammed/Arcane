# Missions: JWE Edition

## What is this?
Missions is a highly gamified, tactical life-management and productivity tracker. Designed with aesthetics inspired by competitive agents and cinematic universes (Valorant, Arcane, Spider-Man, Jurassic World Evolution), it transforms daily chores, long-term goals, and financial tracking into "Missions," "Protocols," and "Objectives."

## Why?
Productivity apps often feel like a chore. Task Dominion bridges the gap between gaming and real life by introducing XP, levels, and system diagnostics (Well-being traits like Resilience, Autonomy, Vitality). By treating life as a series of tactical operations, complete with post-action debriefs and analytics, it makes self-improvement engaging and structured.

---

## Core Systems

### 1. Missions & Protocols (Tasks)
*   **Agents (Main Tasks):** Broad categories like 'Fitness', 'Learning', 'Work'. Each agent has a distinct color code and icon.
*   **Sub-Missions (Subtasks):** Actionable items within an Agent. Can be set as one-off or **Recurring** (resets daily at 00:00).
*   **Checkpoints (Sub-Subtasks):** Granular steps for a Sub-Mission. Can be "Checkable" steps or "Info" notes.
*   **Action Plans:** Each Sub-Mission holds a 'Why' (Strategic Intent), 'What' (Expected Outcome), and 'How' (Checkpoints). 
*   **Time Tracking:** Engage/Halt timers on any Sub-Mission to precisely track session hours.

### 2. Project Engine & Velocity
*   **Projects:** Large-scale objectives linked to an Agent.
*   **Recursive Steps:** Break projects down into infinite levels of nested steps.
*   **Linking:** Project steps can be physically linked to Sub-Missions. Completing the Sub-Mission automatically marks the project step as complete.
*   **Velocity Graph:** Manually log progress snapshots (e.g., 50% done after 10 hours) and the system provides a linear regression forecast on completion time.

### 3. Schedule & Day Plan
*   **Day Plan Dashboard:** Add specific Sub-Missions or Checkpoints to a "Today's Queue" for focused execution without distractions.
*   **Timeline:** A 24-hour visual grid showing exact times you worked on tasks today.
*   **AI Prediction:** Generate a probable schedule for the rest of your day based on your past 14-day history.

---

## Tactical Features

### 1. NORA Neural AI
*   **Chatbot:** A customized persona (Therapist, Tactician, Friend) that knows your active tasks, recent reflections, and known entities.
*   **Dynamic Controls:** Adjust memory span (e.g., look back 7 days vs 30 days), set message limits per session, and inject custom override prompts to fine-tune her personality.
*   **Simulation Suite:** 
    *   *Event Simulator:* Predict how you might handle a future scenario based on past logs.
    *   *Comms Simulator:* NORA roleplays as a specific person from your "Intel" list so you can practice difficult conversations.

### 2. Psychological Biometrics (Wellbeing & XP)
*   **Reflection Logs:** Log events with Triggers, Emotions, and Actions. AI analyzes these and awards XP across 12 psychological traits (Positivity, Resilience, Meaning, etc.).
*   **Dynamic Leveling:** XP and levels are calculated *strictly* from the rolling 7-day momentum. If you stop logging, levels naturally decay, enforcing consistent reflection.

### 3. Intelligence & Assets (Gratitude)
*   **People Intel:** AI extracts mentioned individuals from your logs and builds psychological dossiers/interaction histories.
*   **Asset Management (Gratitude List):** A tactical representation of gratitude. Log 'Skills', 'Resources', 'People', and 'Objects' detailing their *Strategic Value (Why)* and *Expected Yield (What)*.
*   **Auto-Assign:** When viewing a Sub-Mission, the AI can scan your known Assets and auto-assign the tools/people you need to complete it.

### 4. Financial & Health Tracking
*   **Wallet:** Cashflow tracking with daily expense breakdowns and 30-day trends. Includes a "Savings Protocol" with projection trajectories.
*   **Biometrics:** Log water intake, sleep (duration mapping), and physical activity (KM/Mins).
*   **Nutrition:** Natural language food scanning ("I ate 2 eggs and toast") automatically calculates and logs macros via AI.

### 5. Behavioral Override (Atomic Habits)
Manage dopamine and screen time through tactical restriction definitions:
*   **Friction Boost:** Define mandatory delay seconds before opening a distracting app.
*   **Usage Cap:** Set hard daily minute limits.
*   **Accountability Log:** Track clean streaks. Breaking a streak resets it to 0, removing the reward mechanism.

### 6. The Holding Pattern (Someday/Maybe List)
Rooted in GTD principles: get ideas out of your head without commitment.
*   **Zero Friction:** One text field to capture the thought. No dates, tags, or priorities allowed.
*   **Weekly Nudge:** The system highlights items older than 7 days, forcing a conscious decision: execute or delete.

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
*Note: Make sure this file is added to your `.gitignore` to prevent exposing your keys. You can also add custom keys dynamically inside the app's System Settings.*