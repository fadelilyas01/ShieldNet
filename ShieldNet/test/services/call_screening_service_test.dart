import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shieldnet/core/services/call_screening_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CallScreeningService — Tests Pont Natif (Android CallScreening & iOS CallKit)', () {
    const channel = MethodChannel('com.shieldnet.shieldnet/call_screening');
    final service = CallScreeningService();
    final List<MethodCall> methodCalls = [];

    setUp(() {
      methodCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCalls.add(methodCall);
        switch (methodCall.method) {
          case 'requestCallScreeningRole':
            return true;
          case 'isCallScreeningActive':
            return true;
          case 'testDatabaseBridge':
            return {
              'connected': true,
              'platform': 'iOS CallKit',
              'extension_id': 'com.shieldnet.shieldnet.ShieldNetCallExtension',
              'blocked_count': 42,
              'message': 'Pont natif opérationnel',
            };
          case 'checkNumber':
            final args = methodCall.arguments as Map;
            return args['number'] == '+15145550199';
          case 'setContactsOnlyMode':
            return true;
          case 'isContactsOnlyMode':
            return true;
          case 'syncBlockedNumbersToExtension':
            return true;
          case 'reloadCallDirectoryExtension':
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

    test('requestCallScreeningRole invoque le canal natif et retourne le succès', () async {
      final result = await service.requestCallScreeningRole();
      expect(result, isTrue);
      expect(methodCalls.single.method, 'requestCallScreeningRole');
    });

    test('isCallScreeningActive vérifie le statut du rôle natif', () async {
      final result = await service.isCallScreeningActive();
      expect(result, isTrue);
      expect(methodCalls.single.method, 'isCallScreeningActive');
    });

    test('testDatabaseBridge retourne le diagnostic de la couche native', () async {
      final diag = await service.testDatabaseBridge();
      expect(diag['connected'], isTrue);
      expect(diag['platform'], 'iOS CallKit');
      expect(diag['blocked_count'], 42);
    });

    test('checkNumberWithNative vérifie un numéro contre le stockage local', () async {
      final isBlocked = await service.checkNumberWithNative('+15145550199');
      expect(isBlocked, isTrue);

      final isNotBlocked = await service.checkNumberWithNative('+18195550000');
      expect(isNotBlocked, isFalse);
    });

    test('setContactsOnlyMode et isContactsOnlyMode contrôlent le filtrage strict', () async {
      final setSuccess = await service.setContactsOnlyMode(true);
      expect(setSuccess, isTrue);

      final isActive = await service.isContactsOnlyMode();
      expect(isActive, isTrue);
    });

    test('syncBlockedNumbersToNative synchronise les numéros vers CallKit/Android', () async {
      final success = await service.syncBlockedNumbersToNative([15145550199, 14385550122]);
      expect(success, isTrue);
      expect(methodCalls.last.method, 'syncBlockedNumbersToExtension');
      expect((methodCalls.last.arguments as Map)['numbers'], [15145550199, 14385550122]);
    });

    test('reloadCallDirectoryExtension demande le rafraîchissement CallKit', () async {
      final success = await service.reloadCallDirectoryExtension();
      expect(success, isTrue);
      expect(methodCalls.last.method, 'reloadCallDirectoryExtension');
    });
  });
}
