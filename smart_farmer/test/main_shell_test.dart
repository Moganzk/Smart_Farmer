import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_farmer/features/auth/auth_provider.dart';
import 'package:smart_farmer/shell/main_shell.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildApp() {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: AuthProvider.forTesting(),
      child: const MaterialApp(home: MainShell()),
    );
  }

  testWidgets('MainShell renders 5 bottom nav items', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // 5 nav labels
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Tips'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('Tapping Scan tab shows CROP SCANNER', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Initially on Home => DASHBOARD should be visible
    expect(find.text('DASHBOARD'), findsOneWidget);

    // Tap Scan tab
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.text('CROP SCANNER'), findsOneWidget);
  });

  testWidgets('Tapping History tab shows SCAN HISTORY', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('SCAN HISTORY'), findsOneWidget);
  });

  testWidgets('Tapping Tips tab shows FARMING TIPS', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tips'));
    await tester.pumpAndSettle();

    expect(find.text('FARMING TIPS'), findsOneWidget);
  });

  testWidgets('Tapping More tab shows SETTINGS', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.text('SETTINGS'), findsOneWidget);
  });

  testWidgets('More tab has Profile, About, and Logout options', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);

    // Scroll down to find Logout (may be offscreen in SingleChildScrollView)
    await tester.scrollUntilVisible(find.text('Logout'), 100);
    expect(find.text('Logout'), findsOneWidget);
  });

  testWidgets('Logout shows confirmation dialog', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    // Scroll down to find Logout
    await tester.scrollUntilVisible(find.text('Logout'), 100);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(find.text('LOGOUT'), findsOneWidget);
    expect(find.text('Are you sure you want to sign out?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
