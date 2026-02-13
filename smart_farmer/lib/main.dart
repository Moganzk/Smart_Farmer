import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/debug/firebase_diagnostics.dart';
import 'core/services/connectivity_service.dart';
import 'features/auth/auth_provider.dart';
import 'features/notifications/local_notifications_cache.dart';
import 'features/notifications/notifications_service.dart';
import 'features/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load dotenv FIRST — API keys needed everywhere
  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Run diagnostics in debug mode
  if (kDebugMode) {
    runFirebaseDiagnostics(); // fire-and-forget, logs to console
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const SmartFarmerApp());
}

class SmartFarmerApp extends StatelessWidget {
  const SmartFarmerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(
          create: (_) => NotificationsService(cache: LocalNotificationsCache()),
        ),
      ],
      child: MaterialApp(
        title: 'Smart Farmer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
