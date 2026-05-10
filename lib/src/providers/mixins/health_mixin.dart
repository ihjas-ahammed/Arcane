import 'package:flutter/foundation.dart';
import 'package:missions/src/models/health_models.dart';
import 'package:missions/src/providers/mixins/sync_mixin.dart';
import 'package:uuid/uuid.dart';

mixin HealthMixin on ChangeNotifier {
  List<FoodItem> _foodItems =[];
  Map<String, DailyHealthLog> _healthLogs = {};

  List<FoodItem> get foodItems => _foodItems;
  Map<String, DailyHealthLog> get healthLogs => _healthLogs;

  SyncMixin get sync => this as SyncMixin;

  void loadHealthState(Map<String, dynamic> data) {
    if (data['foodItems'] != null) {
      _foodItems = (data['foodItems'] as List).map((e) => FoodItem.fromJson(e)).toList();
    }
    if (data['healthLogs'] != null) {
      final rawLogs = data['healthLogs'] as Map;
      _healthLogs = rawLogs.map((k, v) => MapEntry(k.toString(), DailyHealthLog.fromJson(Map<String, dynamic>.from(v))));
    }
  }

  Map<String, dynamic> getHealthStateMap() {
    return {
      'foodItems': _foodItems.map((e) => e.toJson()).toList(),
      'healthLogs': _healthLogs.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  DailyHealthLog getDailyHealthLog(String dateStr) {
    if (!_healthLogs.containsKey(dateStr)) {
      _healthLogs[dateStr] = DailyHealthLog(dateStr: dateStr);
      // FIX: Schedule state mutation for the next frame to avoid "setState() called during build" exceptions
      Future.microtask(() => sync.markDirty('health'));
    }
    return _healthLogs[dateStr]!;
  }

  void addFoodItem(FoodItem item) {
    _foodItems.add(item);
    sync.markDirty('health');
  }

  void updateFoodItem(FoodItem item) {
    final index = _foodItems.indexWhere((f) => f.id == item.id);
    if (index != -1) {
      _foodItems[index] = item;
      sync.markDirty('health');
    }
  }

  void addMealLog(String dateStr, MealLog log) {
    final hLog = getDailyHealthLog(dateStr);
    hLog.meals.add(log);
    sync.markDirty('health');
  }

  void deleteMealLog(String dateStr, String logId) {
    final hLog = getDailyHealthLog(dateStr);
    hLog.meals.removeWhere((m) => m.id == logId);
    sync.markDirty('health');
  }
  
  void logMealAgain(String dateStr, MealLog originalLog) {
    final hLog = getDailyHealthLog(dateStr);
    final newLog = MealLog(id: const Uuid().v4(), foodItemId: originalLog.foodItemId, timestamp: DateTime.now());
    hLog.meals.add(newLog);
    sync.markDirty('health');
  }

  void addSleepLog(String dateStr, SleepLog log) {
    final hLog = getDailyHealthLog(dateStr);
    hLog.sleepLogs.add(log);
    hLog.sleepLogs.sort((a, b) => b.endTime.compareTo(a.endTime));
    sync.markDirty('health');
  }

  void deleteSleepLog(String dateStr, String logId) {
    final hLog = getDailyHealthLog(dateStr);
    hLog.sleepLogs.removeWhere((l) => l.id == logId);
    sync.markDirty('health');
  }

  void addActivityLog(String dateStr, ActivityLog log) {
    final hLog = getDailyHealthLog(dateStr);
    hLog.activityLogs.add(log);
    hLog.activityLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    sync.markDirty('health');
  }

  void deleteActivityLog(String dateStr, String logId) {
    final hLog = getDailyHealthLog(dateStr);
    hLog.activityLogs.removeWhere((l) => l.id == logId);
    sync.markDirty('health');
  }

  void updateWater(String dateStr, int glasses) {
    final hLog = getDailyHealthLog(dateStr);
    hLog.waterGlasses = glasses;
    sync.markDirty('health');
  }
}