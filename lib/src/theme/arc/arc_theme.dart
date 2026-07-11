/// Arc theme — the complete token vocabulary for the app, split by section.
///
/// JweTheme remains the primitive base (mode flag + core HUD tokens); the
/// Arc* files define a variable for every element that widgets previously
/// hardcoded. Import this barrel to get all sections:
///
///   surfaces  → ArcSurfaces  (backgrounds, panels, overlays, glass)
///   content   → ArcContent   (text/icon hierarchy, on-accent, on-swatch)
///   accents   → ArcAccents   (semantic + extended accents, soft fills)
///   strokes   → ArcStrokes   (borders, hairlines, tracks)
///   effects   → ArcEffects   (shadows, glows, sheens, gradients)
///   palette   → ArcPalette   (fixed data hues: task colors, protocol themes)
library;

export 'arc_surfaces.dart';
export 'arc_content.dart';
export 'arc_accents.dart';
export 'arc_strokes.dart';
export 'arc_effects.dart';
export 'arc_palette.dart';
