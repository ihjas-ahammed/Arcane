import 'package:flutter/material.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/services/home_widget_service.dart';
import 'widgets_studio_models.dart';
import 'widgets_studio_resolvers.dart';

class WidgetsStudioSync {
  static Future<void> pinWidget(
    BuildContext context,
    Future<bool?> Function() pinFn,
    String widgetName,
  ) async {
    final ok = await pinFn();
    if (!context.mounted) return;
    if (ok == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Requested to add $widgetName to Android home screen.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pinning $widgetName to home screen is not supported on this device/launcher.')),
      );
    }
  }

  static Future<void> pushBusToAndroid(
    BusWidgetData bus, {
    BuildContext? context,
  }) async {
    await HomeWidgetService.instance.publishBus(
      origin: bus.origin,
      destination: bus.destination,
      nextTime: bus.nextTime,
      nextSubStop: bus.nextSubStop,
      isOnBus: bus.isOnBus,
      speedKmh: bus.speedKmh,
      minutesRemaining: bus.minutesRemaining,
    );
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bus Widget synchronized with Android OS!')),
      );
    }
  }

  static Future<void> pushTaskToAndroid(
    TaskWidgetData task, {
    BuildContext? context,
  }) async {
    await HomeWidgetService.instance.publishTask(
      hasTask: task.hasTask,
      title: task.title,
      subtitle: task.subtitle,
      isRunning: task.isRunning,
      isCheckpoint: task.isCheckpoint,
      accumulatedSeconds: task.accumulatedSeconds,
      progress: task.progress,
      isPhoenix: false,
      capacity: task.capacity,
      multitaskTasks: task.multitaskTasks,
    );
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task Widget synchronized with Android OS!')),
      );
    }
  }

  static Future<void> pushFinanceToAndroid(
    FinanceWidgetData fin, {
    BuildContext? context,
  }) async {
    await HomeWidgetService.instance.publishFinance(
      balance: fin.balance,
      todaySpend: fin.todaySpend,
      monthSpend: fin.monthSpend,
      budgetPct: fin.budgetPct,
    );
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finance Widget synchronized with Android OS!')),
      );
    }
  }

  static Future<void> pushJournalToAndroid(
    JournalWidgetData jnl, {
    BuildContext? context,
  }) async {
    await HomeWidgetService.instance.publishJournal(
      count: jnl.count,
      wake: jnl.wake,
      morn: jnl.morn,
      aft: jnl.aft,
      eve: jnl.eve,
      night: jnl.night,
    );
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal Widget synchronized with Android OS!')),
      );
    }
  }

  static Future<void> pushAllToAndroid(
    AppProvider provider, {
    BuildContext? context,
    BusWidgetData? busData,
    TaskWidgetData? taskData,
    FinanceWidgetData? financeData,
    JournalWidgetData? journalData,
  }) async {
    final bus = busData ?? WidgetsStudioResolvers.resolveLiveBus(provider);
    final task = taskData ?? WidgetsStudioResolvers.resolveLiveTask(provider);
    final fin = financeData ?? WidgetsStudioResolvers.resolveLiveFinance(provider);
    final jnl = journalData ?? WidgetsStudioResolvers.resolveLiveJournal(provider);

    await HomeWidgetService.instance.publishBus(
      origin: bus.origin,
      destination: bus.destination,
      nextTime: bus.nextTime,
      nextSubStop: bus.nextSubStop,
      isOnBus: bus.isOnBus,
      speedKmh: bus.speedKmh,
      minutesRemaining: bus.minutesRemaining,
    );
    await HomeWidgetService.instance.publishTask(
      hasTask: task.hasTask,
      title: task.title,
      subtitle: task.subtitle,
      isRunning: task.isRunning,
      isCheckpoint: task.isCheckpoint,
      accumulatedSeconds: task.accumulatedSeconds,
      progress: task.progress,
      isPhoenix: false,
      capacity: task.capacity,
      multitaskTasks: task.multitaskTasks,
    );
    await HomeWidgetService.instance.publishFinance(
      balance: fin.balance,
      todaySpend: fin.todaySpend,
      monthSpend: fin.monthSpend,
      budgetPct: fin.budgetPct,
    );
    await HomeWidgetService.instance.publishJournal(
      count: jnl.count,
      wake: jnl.wake,
      morn: jnl.morn,
      aft: jnl.aft,
      eve: jnl.eve,
      night: jnl.night,
    );

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All widgets synchronized with Android OS!')),
      );
    }
  }
}
