# ⚡ Arcane System Upgrade // v2026.9.5

### 📐 Tactical Multi-Plan Height Consistency & Dynamic Layout
- **Multi-Task Row Height Parity**: Wrapped multi-task rows (2-in-1 and 3-in-1 planner & hero cards) with `IntrinsicHeight` and vertical cross-axis stretch, guaranteeing consistent card heights between tasks with and without subtasks or checkpoints.
- **Checkpoint Badges for Multitask Cards**: Standardized active checkpoint status indicators (`Icons.checklist_rounded`) on multitask cards displaying active `${completedCps}/${totalCps}` ratios with instant one-tap dialogs to inspect and toggle checkpoints.
- **Responsive Overflow Shielding**: Dynamic typography scaling and flex constraints preventing horizontal or vertical text overflow in multi-task configurations.

### 🛡️ Unified Tactical HUD Chamfered Border Styling
- **Tactical HUD Card Geometry**: Introduced `TacticalCardBorderPainter` and `Chamfer4CornerClipper` delivering authentic sci-fi angled corner notches and cyan border lines.
- **Cross-Component Border Parity**: Unified tactical border styling across Today Planner cards, Schedule Hero widget, and Android Homescreen preview widgets.
- **Clean Iconography**: Purged decorative emojis in favor of crisp, high-contrast Material and Lucide vector icons.

### 🔄 In-App Updater Version Superiority & Stability
- **Strict Version Superiority Enforcement**: Re-engineered update availability resolution to guarantee older or equal releases (e.g. v2026.9.1) are never offered as available updates, even during forced manual checks.
- **Dual-Tier Version Resolution**: Built-in Android `versionCode` validation backed by semantic version string parsing (`isVersionStringNewer`).
- **Real-Time Latest Build Confirmation**: Clear feedback confirming the active installation is on the latest build.

### 📱 Native Android Homescreen Tactical HUD Overhaul
- **Native RemoteViews Tactical XML Parity**: Completely overhauled `widget_running_task.xml` and Android vector drawables to mirror the in-app Schedule Hero HUD aesthetics.
- **Chamfered 4-Corner Geometry & Brackets**: Implemented precision-angled vector corner notches and reinforced HUD bracket styling for Cyan (`#00F0FF`), Amber (`#FFB547`), Red (`#FF2A4B`), and Dim Standby modes.
- **Multitask RemoteViews Architecture**: Native layout and binding for 2-in-1 and 3-in-1 concurrent task cards with parent hierarchy, 01/02/03 indexing, and live checkpoint counts.
- **HUD Status Bar & Action Controls**: Added status dot, monospace protocol state indicator, `REC` indicator, `DAY PLAN` quick-access navigation, and high-contrast tactical action buttons (`ENGAGE ALL` / `HALT SESSION`, `CHECK`, `FINISH`).

### 🚫 Phoenix Protocol Deprecation
- **Clean Protocol Architecture**: Fully removed deprecated Phoenix protocol remnants and obsolete triangle corner painters for a streamlined, performance-optimized mission execution pipeline.

### 🌓 Complete Dual-Theme Architecture & Light Mode Parity
- **Warm Tactical Paper / Stone Light Theme**: Fully adapted Today Planner screen, Schedule Hero widget, Tactical Card Border painter, and Homescreen widgets to support both Dark (operator midnight) and Light (tactical warm paper/stone) modes via `JweTheme` dynamic tokens.
- **Dynamic Accent & Border Calibration**: Integrated `JweTheme.calibrate` and dynamic `JweTheme.border` / `JweTheme.onAccent` resolution across all tactical chamfered card borders, status indicators, and action buttons for maximum contrast and readability in light mode.
- **Android RemoteViews Native Dual-Theme Support**: Deployed qualified Android resource directories (`res/values/widget_colors.xml` for light mode and `res/values-night/widget_colors.xml` for dark mode), delivering automatic, system-synchronized dual-theme support across all native homescreen widgets without code regressions.
- **Persistent Dual-Theme Engineering Rule**: Established project rule `.agents/rules/dual-theme.md` ensuring all future UI and widget modifications consistently implement and verify both light and dark modes.

