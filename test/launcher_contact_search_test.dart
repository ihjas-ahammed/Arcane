import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:missions/src/screens/launcher/launcher_models.dart';
import 'package:missions/src/screens/launcher/launcher_native.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('arcane/launcher');
  final List<MethodCall> log = [];

  setUp(() {
    log.clear();
    LauncherNative.forceSupportedForTesting = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'hasContactsPermission':
          return true;
        case 'requestContactsPermission':
          return true;
        case 'searchContacts':
          final query = methodCall.arguments['query'] as String;
          if (query.toLowerCase().contains('alex')) {
            return [
              {
                'id': '101',
                'name': 'Alex Mercer',
                'number': '+1 555-0199',
                'cleanNumber': '15550199',
                'type': 'Mobile',
                'phones': [
                  {'number': '+1 555-0199', 'cleanNumber': '15550199', 'type': 'Mobile'},
                  {'number': '+1 555-0200', 'cleanNumber': '15550200', 'type': 'Work'},
                ],
              }
            ];
          }
          return [];
        case 'callNumber':
          return true;
        case 'messageNumber':
          return true;
        case 'openWhatsApp':
          return true;
        case 'openContact':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('LauncherContact Model Tests', () {
    test('LauncherContact parses phones and initials correctly', () {
      final contact = LauncherContact.fromMap({
        'id': '42',
        'name': 'John Tactical Doe',
        'number': '+91 9876543210',
        'cleanNumber': '919876543210',
        'type': 'Mobile',
        'phones': [
          {'number': '+91 9876543210', 'cleanNumber': '919876543210', 'type': 'Mobile'},
          {'number': '0484 223344', 'cleanNumber': '0484223344', 'type': 'Home'},
        ],
      });

      expect(contact.id, equals('42'));
      expect(contact.name, equals('John Tactical Doe'));
      expect(contact.initials, equals('JT'));
      expect(contact.primaryPhone, equals('+91 9876543210'));
      expect(contact.phones.length, equals(2));
      expect(contact.phones[1].type, equals('Home'));
    });

    test('LauncherContact initials edge cases', () {
      final single = LauncherContact.fromMap({'name': 'Morpheus'});
      expect(single.initials, equals('MO'));

      final singleChar = LauncherContact.fromMap({'name': 'Q'});
      expect(singleChar.initials, equals('Q'));

      final empty = LauncherContact.fromMap({'name': '   '});
      expect(empty.initials, equals('?'));
    });
  });

  group('LauncherNative Contacts Bridge Tests', () {
    test('checks permission and searches contacts', () async {
      final hasPerm = await LauncherNative.hasContactsPermission();
      expect(hasPerm, isTrue);

      final results = await LauncherNative.searchContacts('Alex');
      expect(results.length, equals(1));
      expect(results.first.name, equals('Alex Mercer'));
      expect(results.first.phones.length, equals(2));

      expect(log.any((m) => m.method == 'hasContactsPermission'), isTrue);
      expect(log.any((m) => m.method == 'searchContacts'), isTrue);
    });

    test('triggers callNumber, messageNumber, and openWhatsApp actions', () async {
      final callOk = await LauncherNative.callNumber('+15550199');
      expect(callOk, isTrue);
      expect(log.last.method, equals('callNumber'));
      expect(log.last.arguments['number'], equals('+15550199'));

      final msgOk = await LauncherNative.messageNumber('+15550199');
      expect(msgOk, isTrue);
      expect(log.last.method, equals('messageNumber'));

      final waOk = await LauncherNative.openWhatsApp('+15550199');
      expect(waOk, isTrue);
      expect(log.last.method, equals('openWhatsApp'));

      final openOk = await LauncherNative.openContact('101');
      expect(openOk, isTrue);
      expect(log.last.method, equals('openContact'));
    });
  });
}
