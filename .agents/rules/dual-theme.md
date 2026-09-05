---
trigger: always_on
description: Always support and test both Light and Dark themes when creating or modifying UI components.
---

## Dual Theme Support

This app supports dual themes (Dark and Light mode) driven by `JweTheme` and `AppTheme`.

Rules:
- Never hardcode dark/midnight colors (e.g. `Color(0xFF090F16)`, `Color(0xFF05080C)`, `Color(0xFF182533)`, `Colors.white`, neon accents) into UI components, widgets, or canvas painters without adapting to `JweTheme.isLight` / `AppTheme.isLightTheme`.
- For background, surfaces, borders, text, and accents, use `JweTheme` / `AppTheme` getters (e.g. `JweTheme.panel`, `JweTheme.bgCanvas`, `JweTheme.border`, `JweTheme.textWhite`, `JweTheme.textMid`, `JweTheme.textMuted`, `JweTheme.accentCyan`, `JweTheme.accentAmber`, `JweTheme.accentRed`, `JweTheme.onAccent`) or branch on `JweTheme.isLight` to provide the warm tactical paper/stone palette in light mode.
- In custom painters (e.g. tactical borders, chamfer clippers, HUD graphics), ensure stroke colors, fill colors, and corner brackets adapt cleanly to light mode with appropriate contrast and calibrated hues (`JweTheme.calibrate`).
- For native Android widgets, maintain dual-theme parity using `res/values/widget_colors.xml` (light/day default) and `res/values-night/widget_colors.xml` (dark mode), ensuring drawables reference semantic color tokens.
