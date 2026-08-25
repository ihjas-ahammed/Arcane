# ⚡ Arcane System Upgrade // v2026.8.25

### 🚍 Bus Transit Radar & Real-Time Telemetry
- **Location-Aware Tracking**: Automatic nearest transit stop detection with instantaneous multi-tier GPS fallback (zero-delay cached location resolver).
- **Live Transit Telemetry**: Next bus HUD displaying real-time speed, dynamic ETA countdown, and intermediate route progress.
- **Route Progress Timeline**: Interactive journey timeline highlighting intermediate sub-stops as transit progresses.
- **Manual "ON BUS" Mode**: Manual commute trigger calculating elapsed duration, remaining minutes, and dynamic sub-stop progression.

### 🛠️ Transit Network & Sub-Stops Data Editor
- **Full In-App Visual Editor**: Accessible directly from Settings (`Section 8.6`), More screen, and the Bus Radar AppBar.
- **Sub-Stops Manager**: Add, edit, delete, and drag-and-drop reorder intermediate sub-stops with customized distances (km), time offsets (mins), and GPS coordinates.
- **Route & Timetable Customization**: Configure custom routes, transit stops, and departure times with one-tap factory reset.

### 📱 Android Native Homescreen Widgets & Studio
- **Bus Transit Radar Widget**: Brand new native Android widget (`BusWidget.kt`) featuring RemoteViews for next bus departure, active transit telemetry, and quick-launch actions.
- **Widgets Studio**: Interactive preview and testing suite in Settings & More menu allowing live calibration and immediate synchronization of all 4 Android homescreen widgets (Bus, Task, Finance, and Journal).

### 🎨 UI & Theme Polish
- **Title Overflow Fixes**: Resolved text clipping and overflows across AppBar headers, telemetry badges, and cards on compact displays.
- **Light Theme Refinement**: Darkened primary protocol accent colors and calibrated surface contrast for enhanced readability in light mode.
