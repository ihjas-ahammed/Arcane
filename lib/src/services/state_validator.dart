import 'package:missions/src/models/app_state_models.dart';
import 'package:missions/src/models/task_models.dart';
import 'package:missions/src/models/project_models.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/models/finance_models.dart';
import 'package:missions/src/models/skill_models.dart';
import 'package:missions/src/models/tracked_skill_model.dart';
import 'package:missions/src/models/sop_model.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/models/health_models.dart';
import 'package:missions/src/models/trading_models.dart';
import 'package:missions/src/models/trading_psychology_models.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';

void validateTradingState(Map<String, dynamic> state) {
  for (final key in [
    'cashBalance',
    'usdtToInrRate',
    'lastModified',
    'equityPeakINR'
  ]) {
    if (state[key] != null && state[key] is! num)
      throw FormatException('trading.$key must be a number');
  }
  final parsers = <String, Object Function(Map<String, dynamic>)>{
    'holdings': CryptoHolding.fromJson,
    'orders': TradingOrder.fromJson,
    'tradeRecords': TradeRecord.fromJson,
    'equitySnapshots': EquitySnapshot.fromJson,
  };
  for (final entry in parsers.entries) {
    final raw = state[entry.key];
    if (raw == null) continue;
    if (raw is! List)
      throw FormatException('trading.${entry.key} must be a list');
    for (final item in raw) {
      entry.value(Map<String, dynamic>.from(item as Map));
    }
  }
  if (state['riskSettings'] != null)
    TradingRiskSettings.fromJson(
        Map<String, dynamic>.from(state['riskSettings'] as Map));
  if (state['lossAlertsTriggered'] != null &&
      state['lossAlertsTriggered'] is! List)
    throw const FormatException('Trading alerts must be a list');
}

void validateLauncherState(Map<String, dynamic> state) {
  for (final key in ['dock', 'home', 'shelf', 'drawerFolders', 'hidden']) {
    if (state[key] == null) continue;
    if (state[key] is! List ||
        (state[key] as List).any((item) => item is! String))
      throw FormatException('launcher.$key must be a list of strings');
  }
  final parsers = <String, Object Function(Map<String, dynamic>)>{
    'folders': LauncherFolder.fromJson,
    'widgets': LauncherWidgetEntry.fromJson,
    'webLinks': LauncherApp.fromJson,
  };
  for (final entry in parsers.entries) {
    final raw = state[entry.key];
    if (raw == null) continue;
    if (raw is! List)
      throw FormatException('launcher.${entry.key} must be a list');
    for (final item in raw) {
      entry.value(Map<String, dynamic>.from(item as Map));
    }
  }
  if (state['overrides'] != null) {
    for (final item in (state['overrides'] as Map).values) {
      LauncherIconOverride.fromJson(Map<String, dynamic>.from(item as Map));
    }
  }
  if (state['stats'] != null) {
    for (final item in (state['stats'] as Map).values) {
      if (item is! List ||
          item.length != 2 ||
          item.any((value) => value is! num))
        throw const FormatException(
            'Launcher stats must contain numeric pairs');
    }
  }
  if (state['iconPack'] != null && state['iconPack'] is! String)
    throw const FormatException('Launcher icon pack must be a string');
  if (state['quickNotes'] != null && state['quickNotes'] is! String)
    throw const FormatException('Launcher notes must be a string');
  if (state['fullscreen'] != null && state['fullscreen'] is! bool)
    throw const FormatException('Launcher fullscreen must be a boolean');
}

/// Validates edits using model parsers without mutating the provider, launcher,
/// notification scheduler, or the trading singleton.
void validateAppState(Map<String, dynamic> state) {
  final parsers = <String, Object Function(Map<String, dynamic>)>{
    'mainTasks': MainTask.fromJson,
    'projects': Project.fromJson,
    'routineLists': RoutineList.fromJson,
    'goals': GoalModel.fromJson,
    'goalPlaces': GoalPlace.fromJson,
    'transactions': FinanceTransaction.fromJson,
    'categories': FinanceCategory.fromJson,
    'savingsGoals': SavingsGoal.fromJson,
    'accounts': FinanceAccount.fromJson,
    'skills': Skill.fromJson,
    'trackedSkills': TrackedSkill.fromJson,
    'reflectionLogs': ReflectionLog.fromJson,
    'sops': SopModel.fromJson,
    'foodItems': FoodItem.fromJson,
  };
  for (final entry in parsers.entries) {
    final raw = state[entry.key];
    if (raw == null) continue;
    if (raw is! List) throw FormatException('${entry.key} must be a list');
    for (final item in raw) {
      entry.value(Map<String, dynamic>.from(item as Map));
    }
  }
  if (state['settings'] != null)
    AppSettings.fromJson(Map<String, dynamic>.from(state['settings'] as Map));
  if (state['chatbotMemory'] != null)
    ChatbotMemory.fromJson(
        Map<String, dynamic>.from(state['chatbotMemory'] as Map));
  if (state['healthLogs'] != null) {
    for (final item in (state['healthLogs'] as Map).values) {
      DailyHealthLog.fromJson(Map<String, dynamic>.from(item as Map));
    }
  }
  if (state['activeTimers'] != null) {
    for (final item in (state['activeTimers'] as Map).values) {
      ActiveTimerInfo.fromJson(Map<String, dynamic>.from(item as Map));
    }
  }
  if (state['completedByDay'] != null && state['completedByDay'] is! Map)
    throw const FormatException('History must be a map');
  if (state['trading'] != null)
    validateTradingState(Map<String, dynamic>.from(state['trading'] as Map));
  if (state['launcher'] != null)
    validateLauncherState(Map<String, dynamic>.from(state['launcher'] as Map));
}
