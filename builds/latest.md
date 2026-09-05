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

### 🚫 Phoenix Protocol Deprecation
- **Clean Protocol Architecture**: Fully removed deprecated Phoenix protocol remnants and obsolete triangle corner painters for a streamlined, performance-optimized mission execution pipeline.
