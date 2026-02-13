import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smart_farmer/core/theme/app_theme.dart';
import 'package:smart_farmer/features/auth/auth_provider.dart';
import 'package:smart_farmer/features/auth/auth_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget createTestWidget(AuthProvider provider) {
    return ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(theme: AppTheme.darkTheme, home: const AuthScreen()),
    );
  }

  group('AuthScreen widget tests', () {
    late AuthProvider authProvider;

    setUp(() {
      authProvider = AuthProvider.forTesting();
    });

    testWidgets('renders phone mode by default', (tester) async {
      await tester.pumpWidget(createTestWidget(authProvider));
      await tester.pumpAndSettle();

      expect(find.text('Sign in with phone'), findsOneWidget);
      expect(find.text('SEND OTP'), findsOneWidget);
      expect(find.text('Phone number'), findsOneWidget);
      expect(find.text('Use email instead'), findsOneWidget);
      expect(find.text('Email'), findsNothing);
      expect(find.text('Password'), findsNothing);
    });

    testWidgets('switches to email mode on toggle', (tester) async {
      await tester.pumpWidget(createTestWidget(authProvider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use email instead'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in with email'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('SIGN IN'), findsOneWidget);
      expect(find.text('Use phone number instead'), findsOneWidget);
      expect(find.text('Phone number'), findsNothing);
    });

    testWidgets('email mode can toggle register/login', (tester) async {
      await tester.pumpWidget(createTestWidget(authProvider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use email instead'));
      await tester.pumpAndSettle();

      expect(find.text('SIGN IN'), findsOneWidget);
      expect(find.text('No account? Create one'), findsOneWidget);

      await tester.tap(find.text('No account? Create one'));
      await tester.pumpAndSettle();

      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
      expect(find.text('Already have an account? Sign in'), findsOneWidget);
    });

    testWidgets('shows SMART FARMER branding', (tester) async {
      await tester.pumpWidget(createTestWidget(authProvider));
      await tester.pumpAndSettle();

      expect(find.text('SMART FARMER'), findsOneWidget);
    });
  });
}
