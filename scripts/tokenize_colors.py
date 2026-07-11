#!/usr/bin/env python3
"""Tokenize hardcoded colors across lib/ into Arc/Jwe theme variables.

Every mode-sensitive hardcoded color (hex literals, Colors.black/white in
mode-sensitive roles) is replaced with a theme token so the light theme
applies everywhere. Fixed data palettes move to ArcPalette variables.

Idempotent: running twice produces no further changes.
Prints a per-file change report and a list of sites needing manual edits.
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "lib")
ROOT = os.path.normpath(ROOT)

SKIP_FILES = {
    # theme definitions themselves
    "src/theme/jwe_theme.dart",
    "src/theme/app_theme.dart",
    "src/theme/person_info_theme.dart",
    "src/theme/spidey_theme.dart",
    "src/theme/wellbeing_theme.dart",
    # arc tokens
    "src/theme/arc/arc_theme.dart",
    "src/theme/arc/arc_surfaces.dart",
    "src/theme/arc/arc_content.dart",
    "src/theme/arc/arc_accents.dart",
    "src/theme/arc/arc_strokes.dart",
    "src/theme/arc/arc_effects.dart",
    "src/theme/arc/arc_palette.dart",
    # Android notification colors render outside the app theme
    "src/services/notification_service.dart",
}
SKIP_DIRS = (
    "screens_legacy",
)
# legacy valorant tree (lib/screens, lib/widgets, lib/theme) is unreferenced
LEGACY_PREFIXES = ("screens/", "widgets/", "theme/")

ARC_IMPORT = "import 'package:missions/src/theme/arc/arc_theme.dart';"
JWE_IMPORT = "import 'package:missions/src/theme/jwe_theme.dart';"
SPIDEY_IMPORT = "import 'package:missions/src/theme/spidey_theme.dart';"

# ── Structural (whole-expression) replacements, applied first ────────────
STRUCTURAL = [
    # nora backdrop ternaries
    ("JweTheme.isLight ? const Color(0xFFE9EDF5) : const Color(0xFF0F0C1B)",
     "ArcSurfaces.noraDeep"),
    ("JweTheme.isLight ? const Color(0xFFDDE3EE) : const Color(0xFF0A0812)",
     "ArcSurfaces.noraDeeper"),
    # nav glass ternary
    ("JweTheme.isLight ?  Color(0x80FFFFFF) :  Color(0x8008101C)",
     "ArcSurfaces.glass"),
    # chart hairline ternary
    ("(JweTheme.isLight ? const Color(0x0F000000) : const Color(0x1AA8B3C7))",
     "ArcStrokes.hairline"),
    # mode-aware ink already written inline
    ("isLightTheme ? Colors.black.withValues(alpha: 0.07) : Colors.white.withOpacity(0.07)",
     "ArcSurfaces.ink(0.07)"),
]

# ── Hex literal → token ──────────────────────────────────────────────────
HEX_MAP = {
    "FF1F2F40": "ArcStrokes.steel",
    "1AA8B3C7": "ArcStrokes.hairline",
    "3FA8B3C7": "ArcStrokes.hairlineStrong",
    "0DFFFFFF": "ArcStrokes.hairlineFaint",
    "12FFFFFF": "ArcSurfaces.ink(0.07)",
    "0EFFFFFF": "ArcSurfaces.ink(0.055)",
    "15FFFFFF": "ArcSurfaces.ink(0.082)",
    "FF8A2BE2": "ArcAccents.violet",
    "FFB07BFF": "ArcAccents.violetBright",
    "FF3F51B5": "ArcAccents.indigo",
    "6600F0FF": "ArcEffects.cyanGlow(0.4)",
    "3300F0FF": "ArcEffects.cyanGlow(0.2)",
    "0D00F0FF": "ArcEffects.cyanGlow(0.05)",
    "FFFF0055": "ArcAccents.neonPink",
    "FF444444": "ArcSurfaces.disabledFill",
    "FF07121C": "ArcSurfaces.deepPanel",
    "FF061019": "ArcSurfaces.deepPanel",
    "FF06101A": "ArcSurfaces.deepPanel",
    "FF07121D": "ArcSurfaces.deepPanel",
    "FF08101C": "ArcSurfaces.deepPanel",
    "FF0D1E2F": "ArcSurfaces.deepPanelRaised",
    "FF0E2133": "ArcSurfaces.deepPanelRaised",
    "FF0F2136": "ArcSurfaces.deepPanelRaised",
    "FF140C08": "ArcSurfaces.emberPanelDeep",
    "FF261811": "ArcSurfaces.emberPanel",
    "FFCCCCCC": "ArcContent.dossierBody",
    "FF3BFEB9": "ArcAccents.ringGreen",
    "FF4FFFA8": "ArcAccents.ringGreenBright",
    "FF7AFFBD": "ArcAccents.ringGreenSoft",
    "FF445561": "ArcAccents.ringSpikes",
    "FF5D727D": "ArcAccents.ringInactive",
    "1A4AF3C2": "ArcAccents.tealSoft",
    "1AFF5470": "ArcAccents.redSoft",
    "FF0B1623": "PersonInfoTheme.bgPanel",
    # person_detail backdrop gradient pieces
    "FF132030": "SpideyTheme.bgElevated",
    "FF000000": "SpideyTheme.bgDeep",
    # data palettes → ArcPalette (const-safe: ArcPalette members are const)
    "FF5DADE2": "ArcPalette.sky",
    "FFF1C40F": "ArcPalette.sunflower",
    "FFEC7063": "ArcPalette.softRed",
    "FFA569BD": "ArcPalette.softPurple",
    "FF48C9B0": "ArcPalette.softTeal",
    "FFEB984E": "ArcPalette.softOrange",
    "FF58D68D": "ArcPalette.themeHealth",
    "FFE59866": "ArcPalette.themeSocial",
    "FF2ECC71": "ArcPalette.themeNature",
}
# Tokens that are compile-time consts and therefore const-context safe.
CONST_SAFE_PREFIX = "ArcPalette."

# ── Colors.black / Colors.white contextual rules (generic) ───────────────
GENERIC_RULES = [
    (re.compile(r"foregroundColor:\s*Colors\.black\b"), "foregroundColor: JweTheme.onAccent"),
    (re.compile(r"onPrimary:\s*Colors\.black\b"), "onPrimary: JweTheme.onAccent"),
    (re.compile(r"checkColor:\s*Colors\.black\b"), "checkColor: JweTheme.onAccent"),
]

# ── Site-targeted replacements: (file, old, new) ─────────────────────────
TARGETED = [
    ("src/widgets/drawers/wellbeing_drawer.dart",
     "CircularProgressIndicator(strokeWidth: 2, color: Colors.black)",
     "CircularProgressIndicator(strokeWidth: 2, color: JweTheme.onAccent)"),
    ("src/widgets/drawers/wellbeing_drawer.dart",
     "Icon(MdiIcons.sync, size: 18, color: Colors.black)",
     "Icon(MdiIcons.sync, size: 18, color: JweTheme.onAccent)"),
    ("src/screens/onboarding/app_tour_screen.dart",
     "foregroundColor: _currentPage == slides.length - 1 ? Colors.black : JweTheme.textWhite",
     "foregroundColor: _currentPage == slides.length - 1 ? JweTheme.onAccent : JweTheme.textWhite"),
    ("src/screens/settings/data_recovery_screen.dart",
     "GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: Colors.black)",
     "GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: JweTheme.onAccent)"),
    ("src/screens/reflections_archive_screen.dart",
     "const TextStyle(color: Colors.black, fontWeight: FontWeight",
     "TextStyle(color: JweTheme.onAccent, fontWeight: FontWeight"),
    ("src/widgets/bus/bus_schedule_grid.dart",
     "? Colors.black\n", "? JweTheme.onAccent\n"),
    # code/input surfaces
    ("src/widgets/ui/json_editor_widget.dart",
     "fillColor: Colors.black", "fillColor: ArcSurfaces.codeField"),
    ("src/screens/database_editor_screen.dart",
     "color: Colors.black,", "color: ArcSurfaces.codeField,"),
    ("src/widgets/dialogs/ai_generation_prompt_dialog.dart",
     "fillColor: Colors.black.withOpacity(0.3)", "fillColor: ArcSurfaces.inputFill"),
    # scrims
    ("src/screens/project_detail_screen.dart",
     "color: Colors.black.withValues(alpha: 0.4)", "color: ArcSurfaces.dim(0.4)"),
    ("src/widgets/bus/bus_next_card.dart",
     "color: Colors.black.withValues(alpha: 0.2)", "color: ArcSurfaces.dim(0.2)"),
    # shadows
    ("src/screens/schedule/today_planner_screen.dart",
     "shadowColor: Colors.black.withValues(alpha: 0.5)", "shadowColor: ArcEffects.shadow(0.5)"),
    ("src/widgets/ui/sync_indicator.dart",
     "color: Colors.black.withOpacity(0.3)", "color: ArcEffects.shadow(0.3)"),
    ("src/widgets/ui/reflection_log_card.dart",
     "color: Colors.black.withOpacity(0.3)", "color: ArcEffects.shadow(0.3)"),
    # panel overlays / structure inks
    ("src/widgets/ui/hextech_components.dart",
     "..color = Colors.white.withOpacity(0.1)", "..color = ArcSurfaces.ink(0.1)"),
    ("src/screens/finance/savings_detail_screen.dart",
     "BoxDecoration(color: Colors.white.withOpacity(0.2))", "BoxDecoration(color: ArcSurfaces.ink(0.2))"),
    # accent-fill sheen gradient (task header)
    ("src/widgets/cards/task_header_card.dart",
     "Colors.white.withValues(alpha: 0.05),", "ArcEffects.sheen(0.05),"),
    ("src/widgets/cards/task_header_card.dart",
     "Colors.white.withValues(alpha: 0.35),", "ArcEffects.sheen(0.35),"),
]

TOKEN_RE = re.compile(r"\b(?:ArcSurfaces|ArcContent|ArcAccents|ArcStrokes|ArcEffects)\.[a-zA-Z]\w*")


def find_matching_paren(s: str, open_idx: int) -> int:
    depth = 0
    i = open_idx
    while i < len(s):
        c = s[i]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def deconst(src: str, report: list, path: str) -> str:
    """Remove `const ` from constructor expressions that now contain runtime
    tokens. Local `const Color x =` declarations become `final`. Default
    parameter values and static consts are reported for manual handling."""
    # direct: `const ArcX.y` / `const JweTheme.x`
    src = re.sub(r"\bconst\s+((?:ArcSurfaces|ArcContent|ArcAccents|ArcStrokes|ArcEffects|ArcPalette|JweTheme|SpideyTheme|PersonInfoTheme)\.)", r"\1", src)
    # local const declarations that now hold runtime tokens
    src = re.sub(
        r"\bconst\s+(Color\s+\w+\s*=\s*(?:ArcSurfaces|ArcContent|ArcAccents|ArcStrokes|ArcEffects|JweTheme|SpideyTheme|PersonInfoTheme)\.)",
        r"final \1", src)

    # constructor const blocks containing tokens
    changed = True
    while changed:
        changed = False
        for m in re.finditer(r"\bconst\s+([A-Z]\w*(?:\.\w+)?)\s*\(", src):
            open_idx = src.index("(", m.end() - 1)
            close_idx = find_matching_paren(src, open_idx)
            if close_idx == -1:
                continue
            body = src[open_idx:close_idx]
            if TOKEN_RE.search(body) or re.search(r"\b(?:JweTheme|SpideyTheme|PersonInfoTheme)\.", body):
                # skip default parameter values: `= const Foo(...)` preceded by `this.` param or `}` pattern is hard;
                # detect `= const` immediately before (default value or field initializer)
                before = src[max(0, m.start() - 40):m.start()]
                if re.search(r"=\s*$", before.rstrip()[:len(before.rstrip())]) and re.search(r"(this\.\w+\s*=\s*|static\s+const\s+)", before):
                    report.append(f"MANUAL(default/static const): {path}: ...{before[-30:]}const {m.group(1)}(")
                    continue
                src = src[:m.start()] + src[m.start() + len("const "):]
                changed = True
                break
    return src


def ensure_import(src: str, imp: str) -> str:
    if imp in src:
        return src
    lines = src.split("\n")
    last_import = -1
    for i, line in enumerate(lines):
        if line.startswith("import "):
            last_import = i
    if last_import == -1:
        return imp + "\n" + src
    lines.insert(last_import + 1, imp)
    return "\n".join(lines)


def main():
    write = "--write" in sys.argv
    total_changes = 0
    manual_report: list = []

    for dirpath, _, fns in os.walk(ROOT):
        for fn in sorted(fns):
            if not fn.endswith(".dart"):
                continue
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, ROOT).replace("\\", "/")
            if rel in SKIP_FILES or rel.startswith(LEGACY_PREFIXES) or any(d in rel for d in SKIP_DIRS):
                continue
            src = open(full, encoding="utf-8").read()
            orig = src

            for old, new in STRUCTURAL:
                src = src.replace(old, new)

            for (tfile, old, new) in TARGETED:
                if rel == tfile:
                    if old in src:
                        src = src.replace(old, new)
                    elif new not in src:
                        manual_report.append(f"TARGET MISS: {rel}: {old[:60]!r}")

            def hex_sub(m):
                hexval = m.group(1).upper()
                return HEX_MAP.get(hexval, m.group(0))

            src = re.sub(r"Color\(0x([0-9A-Fa-f]{8})\)", hex_sub, src)

            for rx, new in GENERIC_RULES:
                src = rx.sub(new, src)

            if src != orig:
                src = deconst(src, manual_report, rel)
                # `const ArcPalette.x` never existed; ArcPalette is const-safe,
                # so restore no-op. Ensure imports for whatever tokens appear.
                if TOKEN_RE.search(src) or "ArcPalette." in src:
                    src = ensure_import(src, ARC_IMPORT)
                if re.search(r"\bJweTheme\.", src):
                    src = ensure_import(src, JWE_IMPORT)
                if re.search(r"\bSpideyTheme\.", src):
                    src = ensure_import(src, SPIDEY_IMPORT)
                n = sum(1 for a, b in zip(orig.split("\n"), src.split("\n")) if a != b) + abs(
                    src.count("\n") - orig.count("\n"))
                total_changes += n
                print(f"{'WROTE' if write else 'WOULD'} {rel}: ~{n} lines")
                if write:
                    open(full, "w", encoding="utf-8").write(src)

    print(f"\ntotal ~{total_changes} changed lines")
    if manual_report:
        print("\n== MANUAL FOLLOW-UPS ==")
        for r in manual_report:
            print(" ", r)


if __name__ == "__main__":
    main()
