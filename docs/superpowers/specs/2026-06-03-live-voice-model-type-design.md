# Live Voice Model Type — Design

Date: 2026-06-03

## Goal

Add a third model category, `liveModels`, that talks to the Gemini **Live API
over WebSocket in TEXT mode**. The Live API has a separate quota and lower
latency than the HTTP `generateContent` endpoint, so Nora gets faster responses
and fewer rate-limit failures. Nora uses a live model by default and
automatically falls back to the existing HTTP `liteModels` if the live socket
fails.

Text in / text out only in this pass. Audio is out of scope (the socket session
can support it later without rearchitecting).

## Default model

`gemini-3.1-flash-live-preview` — latest free flash-live model as of 2026.
(`gemini-2.0-flash-live-001` was shut down Dec 2025.)

## Changes

### 1. `lib/src/models/app_state_models.dart` — `AppSettings`
- Add `List<String> liveModels`, default `['gemini-3.1-flash-live-preview']`.
- Wire into constructor default, `fromJson`, `toJson`, mirroring `liteModels`.

### 2. `lib/src/services/ai_service.dart` — `AIService`
- Add private `Future<String> _liveTextCall(String apiKey, String modelName, String prompt)`:
  - Connect `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=<apiKey>`.
  - Send `setup`: `{ model: "models/<modelName>", generationConfig: { responseModalities: ["TEXT"] } }`; wait for `setupComplete`.
  - Send `clientContent`: user turn with the prompt, `turnComplete: true`.
  - Accumulate `serverContent.modelTurn.parts[].text` until `turnComplete` / `generationComplete`.
  - Close socket, return accumulated text. Throw on socket error or empty text
    so the rotation loop can fall back.
- In `queryNeuralArchive`'s `requestFn`, branch: if `modelName.contains('live')`
  call `_liveTextCall`, else the existing `genai.GenerativeModel` HTTP path.
  Existing model+key rotation/fallback loop is unchanged.

### 3. `pubspec.yaml`
- Add `web_socket_channel: ^3.0.0`.

### 4. `lib/src/providers/app_provider.dart` (~line 1359)
- Nora default candidates:
  `session.modelOverride != null ? [session.modelOverride!] : [...settings.liveModels, ...settings.liteModels]`.

### 5. UI
- `lib/src/widgets/views/settings_view.dart`: add a "Live Models" editor section
  alongside lite/heavy.
- `lib/src/widgets/dialogs/nora_control_panel.dart`: include live models in the
  per-session model dropdown.

## Decisions

- Any model name containing `'live'` triggers the WebSocket path. Simple, robust.
- Live socket errors auto-fall-back to `liteModels` via the existing rotation loop.
