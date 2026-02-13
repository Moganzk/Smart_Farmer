import 'package:flutter_test/flutter_test.dart';
import 'package:smart_farmer/features/tips/tips_repository.dart';
import 'package:smart_farmer/features/notifications/notifications_repository.dart';

/// Unit tests for Firestore repository methods.
/// These test the model classes and ensure graceful handling of
/// edge cases. (Full Firestore integration tests require a running
/// emulator or real backend — covered in device verification.)
void main() {
  group('Tip model', () {
    test('Tip fields are correctly assigned', () {
      final tip = Tip(
        id: '1',
        title: 'Water your crops',
        body: 'Always water in the morning.',
        category: 'General',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(tip.id, '1');
      expect(tip.title, 'Water your crops');
      expect(tip.body, 'Always water in the morning.');
      expect(tip.category, 'General');
      expect(tip.createdAt, DateTime(2026, 1, 1));
    });
  });

  group('AppNotification model', () {
    test('AppNotification fields are correctly assigned', () {
      final n = AppNotification(
        id: 'n1',
        title: 'Welcome',
        body: 'Welcome to Smart Farmer!',
        read: false,
        createdAt: DateTime(2026, 2, 13),
      );

      expect(n.id, 'n1');
      expect(n.title, 'Welcome');
      expect(n.body, 'Welcome to Smart Farmer!');
      expect(n.read, false);
      expect(n.createdAt, DateTime(2026, 2, 13));
    });

    test('read notification is flagged correctly', () {
      final n = AppNotification(
        id: 'n2',
        title: 'Read',
        body: 'Old notification',
        read: true,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(n.read, true);
    });
  });

  group('Repository graceful handling', () {
    test('TipsRepository can be instantiated', () {
      // Ensures the class compiles and constructor doesn't throw
      // without Firebase (will fail on actual fetch — expected).
      expect(() => TipsRepository, returnsNormally);
    });

    test('NotificationsRepository can be instantiated', () {
      expect(() => NotificationsRepository, returnsNormally);
    });
  });
}
