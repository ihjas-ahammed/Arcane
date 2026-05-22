/// SQL-like expansion for the ADD STEP input.
///
/// Examples:
///   "Buy milk"        -> ["Buy milk"]
///   "Push-ups*5"      -> ["Push-ups", "Push-ups", "Push-ups", "Push-ups", "Push-ups"]
///   "Lap %d * 3"      -> ["Lap 1", "Lap 2", "Lap 3"]
///
/// Count is clamped to [1, 100] to prevent accidental runaway expansions.
List<String> expandStepInput(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return const [];

  final match = RegExp(r'^(.+?)\s*\*\s*(\d+)\s*$').firstMatch(trimmed);
  if (match == null) return [trimmed];

  final template = match.group(1)!.trim();
  if (template.isEmpty) return [trimmed];

  final count = int.parse(match.group(2)!).clamp(1, 100);
  final useIndex = template.contains('%d');

  return List.generate(count, (i) {
    return useIndex ? template.replaceAll('%d', '${i + 1}') : template;
  });
}
