# ⚡ Arcane System Upgrade // v2026.9.2

### 📱 Homescreen Widgets Studio & Native Widget Parity
- **Pin to Homescreen Support**: Added direct widget pinning actions inside the Homescreen Widgets Studio using Android's native `requestPinWidget` API.
- **Pixel-Perfect Widget Parity**: Aligned colors, contrast, typography, and layout metrics between Flutter widget previews and Android XML RemoteViews (`#0D1426` panel background, `#EAECF3` white text).
- **Clean Telemetry Readouts**: Removed cluttering minute countdown suffixes (`(Xm)`) from the main bus departure display across both native Kotlin and Flutter preview widgets.
- **Real-Time Data Streaming**: Previews now reflect live state directly from `AppProvider` and `BusLocationService` with collapsible interactive test controls.

### 🚌 Transit Radar & Directional Dispatch Overhaul
- **Strict Directional Timetables**: Fixed route matching to ensure origin/destination directions (`A → B` vs `B → A`) maintain completely separate, independent departure timetables.
- **Dynamic Last-Selected Focus**: Bus widget automatically synchronizes with the user's active route focus in the app and responds to in-app or native widget swap triggers.
- **Header Layout Polish**: Refactored tactical header bar to eliminate layout clipping on narrow mobile viewports.

### 🧬 Biometrics & Health Telemetry Refinements
- **DropNA Metric-Specific Averages**: 30-day health averages (Calories, Protein, Carbs, Fats, Sleep, Water, Workout Duration, Locomotion) are now calculated strictly over days with recorded entries rather than dividing across a shared day counter.
- **Entry Day Count Telemetry**: Displays unique recorded day counts for each metric (e.g., `1373 / 2200 kcal (24d avg)`).
- **Redesigned Compact Toolbar**: Upgraded Biometrics TabBar to a sleek horizontal `<small_icon> <label>` design (`LOGS`, `NUTRITION`, `STATS`).
- **Stacked Macro Layout**: Reorganized macro progress metrics with titles on top and progress bars underneath to prevent horizontal text collision.

### 🛠️ SOP Protocols & Project Note Enhancements
- **Auto-Scaling SOP Title**: Resolved title truncation in SOP Directory with responsive scaling.
- **Editable Project Logs**: Made project logs and notes editable with slide-right delete and long-press edit gestures.
- **State Preservation**: Reinforced deep checkpoint restoration during task completion and deletion undo.
