import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/models/chatbot_models.dart';
import 'package:missions/src/models/goal_model.dart';
import 'package:missions/src/models/skill_models.dart';
import 'package:missions/src/models/finance_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/utils/external_ai_briefing_helper.dart';
import 'package:missions/src/widgets/ui/tactical_briefing_indicator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExternalAiBriefingHelper Tests', () {
    late AppProvider provider;
    final now = DateTime(2026, 10, 1, 12, 0);

    setUp(() {
      provider = AppProvider.forTest();

      // Populate completedByDay with daily, weekly, and monthly reports
      final cByDay = <String, dynamic>{
        '2026-10-01': {
          'aiBriefing': {
            'summary': 'Great tactical focus on coding and architecture.',
            'grateful_today': [
              {'text': 'Quiet morning focus', 'icon_type': 'mind'},
              {'text': 'Clean code architecture', 'icon_type': 'work'},
            ],
          },
        },
        '2026-09-28': {
          'aiBriefing': {'summary': 'Solid execution on milestones.'},
          'weeklyReport': {'summary': 'Strong weekly performance with 85% goal completion.'},
        },
        '2026-09-15': {
          'aiBriefing': {'summary': 'Rest and recovery day.'},
          'weeklyReport': {'summary': 'Mid-month calibration.'},
        },
        '2026-09-01': {
          'monthlyReport': {'narrative': 'September was a transformative month of deep work.'},
        },
        '2025-11-01': {
          'monthlyReport': {'narrative': 'November last year.'},
        },
      };
      provider.setCompletedByDay(cByDay);

      // Add reflection logs
      provider.reflectionLogs.addAll([
        ReflectionLog(
          id: 'log1',
          timestamp: DateTime(2026, 10, 1, 9, 30),
          trigger: 'Morning planning session',
          emotion: 'Focused and determined',
          reason: 'Clear objectives mapped out',
          action: 'Executed sprint tasks sequentially',
          aiFeedback: 'Great tactical clarity',
          needs: {'Discipline': 30, 'Focus': 25},
        ),
        ReflectionLog(
          id: 'log2',
          timestamp: DateTime(2026, 9, 29, 14, 0),
          trigger: 'Complex refactor challenge',
          emotion: 'Curious and calm',
          reason: 'Broken down into small steps',
          action: 'Implemented clean abstractions',
          aiFeedback: 'Continuous progression',
          needs: {'Wisdom': 20},
        ),
      ]);

      // Add goals
      provider.goals.addAll([
        GoalModel(
          id: 'g1',
          title: 'Daily Code Sprint',
          scope: GoalScope.daily,
          metricType: GoalMetricType.check,
          isCompleted: true,
          placeId: 'work',
        ),
        GoalModel(
          id: 'g2',
          title: 'Weekly Systems Review',
          scope: GoalScope.weekly,
          metricType: GoalMetricType.check,
          currentValue: 3,
          targetValue: 5,
        ),
      ]);

      // Add transactions
      provider.transactions.addAll([
        FinanceTransaction(
          id: 'tx1',
          amount: 250,
          isIncome: false,
          categoryId: 'Food',
          timestamp: DateTime(2026, 10, 1, 8, 30),
          note: 'Coffee & Breakfast',
        ),
        FinanceTransaction(
          id: 'tx2',
          amount: 50000,
          isIncome: true,
          categoryId: 'Salary',
          timestamp: DateTime(2026, 9, 30, 15, 0),
          note: 'Contract Milestone Payment',
        ),
      ]);

      // Add known people
      provider.chatbotMemory.people.add(
        PersonInfo(
          id: 'p1',
          name: 'Sarah',
          relation: 'Collaborator',
          details: 'Lead systems designer',
        ),
      );
    });

    test('buildExportData packages historical briefs correctly', () {
      final data = ExternalAiBriefingHelper.buildExportData(
        provider: provider,
        targetDate: now,
        type: BriefingType.daily,
      );

      final historical = data['historical_briefs'] as Map<String, dynamic>;
      final weekly = historical['weekly_briefs_last_30_days'] as List;
      final monthly = historical['monthly_briefs_last_year'] as List;
      final daily = historical['daily_briefs_last_7_days'] as List;

      // 2026-09-28 and 2026-09-15 are within 30 days
      expect(weekly.length, greaterThanOrEqualTo(2));
      expect(weekly.any((w) => w['date'] == '2026-09-28'), isTrue);

      // 2026-09-01 and 2025-11-01 are within 365 days
      expect(monthly.length, greaterThanOrEqualTo(2));
      expect(monthly.any((m) => m['date'] == '2026-09-01'), isTrue);

      // 2026-10-01 and 2026-09-28 are within 7 days
      expect(daily.length, greaterThanOrEqualTo(2));
      expect(daily.any((d) => d['date'] == '2026-10-01'), isTrue);
      expect(daily.any((d) => d['date'] == '2026-09-28'), isTrue);
    });

    test('buildExportData telemetry window adapts to briefing type (7d vs 30d)', () {
      final dailyData = ExternalAiBriefingHelper.buildExportData(
        provider: provider,
        targetDate: now,
        type: BriefingType.daily,
      );
      final metaDaily = dailyData['meta'] as Map<String, dynamic>;
      expect(metaDaily['telemetry_window_days'], equals(7));

      final monthlyData = ExternalAiBriefingHelper.buildExportData(
        provider: provider,
        targetDate: now,
        type: BriefingType.monthly,
      );
      final metaMonthly = monthlyData['meta'] as Map<String, dynamic>;
      expect(metaMonthly['telemetry_window_days'], equals(30));
    });

    test('buildExportData includes reflections, goals, finance, and people', () {
      final data = ExternalAiBriefingHelper.buildExportData(
        provider: provider,
        targetDate: now,
        type: BriefingType.daily,
      );

      final telemetry = data['activity_telemetry'] as Map<String, dynamic>;
      final reflections = telemetry['reflections'] as List;
      final goals = telemetry['goals'] as List;
      final finance = telemetry['finance'] as Map<String, dynamic>;
      final people = telemetry['known_people'] as List;

      expect(reflections.length, equals(2));
      expect(goals.length, equals(2));
      expect(finance['total_income'], equals(50000.0));
      expect(finance['total_expense'], equals(250.0));
      expect(people.length, equals(1));
      expect(people.first['name'], equals('Sarah'));
    });

    test('buildPrompt generates complete prompts with schemas for all 3 types', () {
      final dailyPrompt = ExternalAiBriefingHelper.buildPrompt(
        type: BriefingType.daily,
        targetDate: now,
        provider: provider,
      );
      expect(dailyPrompt.contains('DAILY TACTICAL BRIEFING'), isTrue);
      expect(dailyPrompt.contains('"quote_reflections"'), isTrue);
      expect(dailyPrompt.contains('"suggested_sops"'), isTrue);
      expect(dailyPrompt.contains('"contingency"'), isTrue);

      final weeklyPrompt = ExternalAiBriefingHelper.buildPrompt(
        type: BriefingType.weekly,
        targetDate: now,
        provider: provider,
      );
      expect(weeklyPrompt.contains('7-DAY REVIEW REPORT'), isTrue);
      expect(weeklyPrompt.contains('"health_intel"'), isTrue);
      expect(weeklyPrompt.contains('"creative_story"'), isTrue);

      final monthlyPrompt = ExternalAiBriefingHelper.buildPrompt(
        type: BriefingType.monthly,
        targetDate: now,
        provider: provider,
      );
      expect(monthlyPrompt.contains('MONTHLY BRIEFING'), isTrue);
      expect(monthlyPrompt.contains('"after_action_review"'), isTrue);
      expect(monthlyPrompt.contains('"best_possible_self"'), isTrue);
    });

    test('parseAiOutput handles pure JSON and markdown fences', () {
      const pureJson = '{"summary": "Solid focus today.", "small_win": "Completed sprint"}';
      final parsed1 = ExternalAiBriefingHelper.parseAiOutput(pureJson);
      expect(parsed1['summary'], equals('Solid focus today.'));
      expect(parsed1['small_win'], equals('Completed sprint'));

      const fencedJson = '''
```json
{
  "summary": "Fenced output with markdown.",
  "small_win": "Code review passed"
}
```
''';
      final parsed2 = ExternalAiBriefingHelper.parseAiOutput(fencedJson);
      expect(parsed2['summary'], equals('Fenced output with markdown.'));

      const chatterJson = '''
Here is your daily tactical briefing synthesis:

```json
{
  "summary": "Surrounded by chatter.",
  "savor_moment": "Sunset walk"
}
```

Hope this helps your evening review!
''';
      final parsed3 = ExternalAiBriefingHelper.parseAiOutput(chatterJson);
      expect(parsed3['summary'], equals('Surrounded by chatter.'));
      expect(parsed3['savor_moment'], equals('Sunset walk'));
    });

    test('parseAiOutput throws FormatException on invalid inputs', () {
      expect(() => ExternalAiBriefingHelper.parseAiOutput(''), throwsA(isA<FormatException>()));
      expect(() => ExternalAiBriefingHelper.parseAiOutput('No json here at all'), throwsA(isA<FormatException>()));
      expect(() => ExternalAiBriefingHelper.parseAiOutput('["not", "a", "map"]'), throwsA(isA<FormatException>()));
    });

    test('saveBriefing saves daily briefing and syncs grateful assets', () async {
      final briefingData = {
        'summary': 'External AI synthesized summary',
        'grateful_today': [
          {'text': 'Morning espresso', 'icon_type': 'food'},
          {'text': 'Helpful code review', 'icon_type': 'social'},
        ],
      };

      await ExternalAiBriefingHelper.saveBriefing(
        provider: provider,
        type: BriefingType.daily,
        targetDate: now,
        data: briefingData,
      );

      final saved = provider.getTacticalBriefing('2026-10-01');
      expect(saved, isNotNull);
      expect(saved!['summary'], equals('External AI synthesized summary'));

      // Check gratitude assets synced into memory
      final gratitude = provider.chatbotMemory.gratitudeList;
      expect(gratitude.any((g) => g.name == 'Morning espresso'), isTrue);
      expect(gratitude.any((g) => g.name == 'Helpful code review'), isTrue);
    });
  });
}
