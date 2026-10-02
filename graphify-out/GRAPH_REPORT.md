# Graph Report - .  (2026-10-02)

## Corpus Check
- Large corpus: 649 files · ~5,17,498 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder, or use --no-semantic to run AST-only.

## Summary
- 3668 nodes · 5905 edges · 0 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output
- Edge kinds: contains: 2803 · MODIFIES: 2415 · PARENT_OF: 328 · ON_BRANCH: 327 · calls: 21 · rationale_for: 10 · method: 1


## Input Scope
- Requested: auto
- Resolved: committed (source: default-auto)
- Included files: 649 · Candidates: 1639
- Excluded: 1 untracked · 25624 ignored · 2 sensitive · 0 missing committed
- Recommendation: Use --scope all or graphify.yaml inputs.corpus for a knowledge-base folder.

## Graph Freshness
- Built from Git commit: `a38ce31`
- Compare this hash to `git rev-parse HEAD` before trusting freshness-sensitive graph output.
## God Nodes (most connected - your core abstractions)

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities

## Knowledge Gaps
- **1053 isolated node(s):** `Checks if a file or directory should be ignored based on .gitignore patterns.`, `Reads the .gitignore file and returns a list of patterns.     Handles comments a`, `Creates a zip archive of a Flutter project, excluding files and directories`, `DefaultFirebaseOptions`, `LogbookScreen` (+1048 more)
  These have ≤1 connection - possible missing edges or undocumented components.