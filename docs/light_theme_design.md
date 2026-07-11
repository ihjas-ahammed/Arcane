# Light Theme — Design & Color Psychology Notes

Why the old light mode read as "inverted colors", what the research says, and how the new
stable light theme is built. Compiled 2026-07-12.

## Diagnosis of the "inverted" look

1. **~330 hardcoded colors in widgets** (127 hex literals, 208 `Colors.*`) never consulted the
   theme, so flipping the mode changed only part of the screen — classic inversion feel.
2. **48 `foregroundColor: Colors.black` sites** on accent buttons. Dark-mode accents are bright
   (black text correct); light-mode accents are dark → black-on-dark buttons.
3. **`calibrate()` crushed accents** to lightness 0.12–0.28 — every accent became near-black ink,
   killing hue identity.
4. **Cold blue-slate surfaces + pure white panels + pure `#000` text** — clinical, harsh, and
   unrelated to the app's warm tactical-amber identity.
5. **White-alpha overlays** (sheens, grids, idle segments) drawn on white panels = invisible.
6. **WellbeingTheme neon trait colors** (ghost white, lawn green, cyan) illegible on light panels.

## Research → decisions

- **Warm off-white surfaces, never pure white**: warm neutrals (cream/stone family) reduce eye
  strain across long sessions and are the current reaction against cold corporate white
  ([Smashing Magazine — psychology of color in UX](https://www.smashingmagazine.com/2025/08/psychology-color-ux-design-digital-products/),
  [Colorhero — modern UI color schemes](https://colorhero.io/blog/modern-ui-color-schemes-users-love),
  [MockFlow — color psychology 2025](https://mockflow.com/blog/color-psychology-in-ui-design)).
  → Canvas `#F5F2EC`, panel `#FCFBF8`, deep `#ECE8E1`, elevated `#E9E4DB`.
- **Off-black text, not `#000`**: pure black on white is harsh; warm gray hierarchy
  ([Percee — dark vs light UX](https://www.perceedigital.com/blogs/dark-mode-vs-light-mode-ux-implications-design-best-practices/)).
  → `#211D18` / `#4A443C` / `#837B70`.
- **Keep hue identity in accents; darken for contrast**: WCAG needs 4.5:1 for normal text and
  3:1 for UI components
  ([WCAG 1.4.3](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html),
  [WebAIM contrast](https://webaim.org/articles/contrast/),
  [Make Things Accessible — WCAG 2.2 AA](https://www.makethingsaccessible.com/guides/contrast-requirements-for-wcag-2-2-level-aa/)).
  → primary sky `#026AA2`, teal `#0F766E`, emerald `#047857`, rose `#BE123C`, bronze `#B45309`,
  violet `#6D28D9`. `calibrate()` retuned: saturation ≤ 0.80, lightness clamped to 0.28–0.40
  (yellows 0.24–0.34 — they need more darkening), so user-selected task colors stay recognizably
  themselves.
- **Amber/blue tactical identity preserved**: amber-family warmth aids alertness/energy, blue
  aids focus/trust; the amber+cyan complementary pairing is the canonical tactical-HUD scheme
  ([Amber color psychology](https://colortheoryexplained.com/amber-color-psychology/),
  [The Color Atlas — blue](https://thecoloratlas.org/blue-color-meaning/)).
  No hue swaps between modes.
- **On-accent contrast is a token, not a constant**: `JweTheme.onAccent` = white in light
  (accents dark), black in dark (accents bright). All 48 broken sites now use it.
- **Overlays flip with the mode**: `ArcSurfaces.ink(a)` is black-based on paper, white-based on
  midnight. Shadows stay black in both modes but are softened (×0.45 alpha) on paper.

## Architecture

```
lib/src/theme/
  jwe_theme.dart          ← primitive base: mode flag + core HUD tokens (retuned light values)
  app_theme.dart          ← Material ThemeData + legacy fh* tokens (delegates light → JweTheme)
  spidey_theme.dart       ← dossier palette (light → warm paper system)
  person_info_theme.dart  ← dossier CSS-var mirror (light → warm paper system)
  wellbeing_theme.dart    ← trait colors, now mode-aware
  arc/
    arc_theme.dart        ← barrel
    arc_surfaces.dart     ← canvas/panels/deep+ember panels/nora/glass/input/ink/dim
    arc_content.dart      ← text hierarchy delegates + onAccent + onSwatch + dossierBody
    arc_accents.dart      ← violet/indigo/neons/timer-ring family/soft tone fills
    arc_strokes.dart      ← steel/hairline(+strong/faint)/border delegates
    arc_effects.dart      ← shadow()/sheen()/cyanGlow()/dossier gradients
    arc_palette.dart      ← fixed data hues (task swatches, protocol themes)
```

`scripts/tokenize_colors.py` performed (and can re-perform — it is idempotent) the migration of
hardcoded widget colors to these tokens: hex literals, `Colors.black/white` in mode-sensitive
roles, gradients, sheens, and scrims, including de-`const`ing expressions that now hold runtime
tokens. Fixed data palettes (user task colors, protocol theme hues) intentionally do not flip
with the mode; light-mode legibility for them is handled at point of use by `calibrate()`.

## Verification checklist for manual testing (user)

1. Settings → theme: system / dark / light all switch live.
2. Buttons: every accent button label/icon readable in light (no black-on-dark).
3. Dossier screens (people/person detail): warm panels, steel borders visible, no white-on-white.
4. Charts: idle bars/tracks visible on paper; wellbeing trait colors legible.
5. Timer ring, NFS bus components, bottom nav glass, snackbars, date pickers.
6. Task color selection: pick a neon task color and confirm headers/accents stay readable in light.
