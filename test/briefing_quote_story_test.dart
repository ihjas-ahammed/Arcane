import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_dart/firebase_dart.dart' as fd;
import 'package:missions/src/providers/app_provider.dart';
import './mock.dart';

void main() {
  setupFirebaseAuthMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
    try {
      fd.FirebaseDart.setup(storagePath: '/tmp/firebase_test');
      await fd.Firebase.initializeApp(
        options: const fd.FirebaseOptions(
          apiKey: 'mock_api_key',
          appId: 'mock_app_id',
          messagingSenderId: 'mock_sender_id',
          projectId: 'mock_project_id',
        ),
      );
    } catch (_) {}
  });

  group('Briefing Quotes & Stories Uniqueness Tests', () {
    test('getPreviouslyUsedQuoteAuthors extracts and deduplicates authors correctly', () {
      final provider = AppProvider.forTest();
      provider.setCompletedByDay({
        '2026-08-18': {
          'startDayReport': {
            'motivational_quote': {
              'quote': 'The impediment to action advances action.',
              'author': 'Marcus Aurelius',
            },
          },
        },
        '2026-08-19': {
          'startDayReport': {
            'motivational_quote': {
              'quote': 'Waste no more time arguing what a good man should be. Be one.',
              'author': ' — Marcus Aurelius ',
            },
          },
        },
        '2026-08-20': {
          'startDayReport': {
            'motivational_quote': {
              'quote': 'I learned very early the difference between knowing the name of something and knowing something.',
              'author': 'Richard Feynman',
            },
          },
        },
        '2026-08-21': {
          'startDayReport': {
            'motivational_quote': '"Somewhere, something incredible is waiting to be known." — Carl Sagan',
          },
        },
      });

      final authors = provider.getPreviouslyUsedQuoteAuthors();

      expect(authors.length, 3);
      expect(authors.contains('Marcus Aurelius'), isTrue);
      expect(authors.contains('Richard Feynman'), isTrue);
      expect(authors.contains('Carl Sagan'), isTrue);
    });

    test('getPreviouslyUsedQuotes collects full list of quotes with attribution', () {
      final provider = AppProvider.forTest();
      provider.setCompletedByDay({
        '2026-08-20': {
          'startDayReport': {
            'motivational_quote': {
              'quote': 'Nature does not hurry, yet everything is accomplished.',
              'author': 'Lao Tzu',
            },
          },
          'aiBriefing': {
            'quote_reflections': [
              {'user_quote': 'Finished the core refactor today.'},
            ],
          },
        },
      });

      final quotes = provider.getPreviouslyUsedQuotes();

      expect(quotes.contains('"Nature does not hurry, yet everything is accomplished." — Lao Tzu'), isTrue);
      expect(quotes.contains('"Finished the core refactor today."'), isTrue);
    });

    test('getPreviouslyUsedStories extracts stories from cached and day data', () async {
      final provider = AppProvider.forTest();

      await provider.saveWeeklyReport('2026-08-14', {
        'creative_story': {
          'title': 'Ada Lovelace: The First Algorithm',
          'story': 'In 1843, Ada created the first algorithm for Babbage engine.',
          'takeaway': 'See the big picture structure.',
        },
      });

      await provider.saveMonthlyReport('2026-08-01', {
        'creative_story': {
          'title': 'Alexander von Humboldt and Nature Unity',
          'story': 'Humboldt mapped connections across mountains and climates.',
          'takeaway': 'Everything is connected.',
        },
      });

      final stories = provider.getPreviouslyUsedStories();

      expect(stories.length, 2);
      expect(stories.any((s) => s.contains('Ada Lovelace: The First Algorithm')), isTrue);
      expect(stories.any((s) => s.contains('Alexander von Humboldt and Nature Unity')), isTrue);

      // Verify that completedByDay also retained weeklyReport and monthlyReport
      expect(provider.completedByDay['2026-08-14']?['weeklyReport'], isNotNull);
      expect(provider.completedByDay['2026-08-01']?['monthlyReport'], isNotNull);
    });
  });
}
