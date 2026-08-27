import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'screens/main_shell.dart';
import 'screens/startup_ad_gate.dart';
import 'firebase_options.dart';
import 'services/deep_link_service.dart';
import 'services/favorites_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start listening early so a cold-start iOS custom URL is not missed.
  DeepLinkService.instance.start();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(
      nizikFirebaseMessagingBackgroundHandler,
    );

    await NotificationService.instance.initialize();
  } catch (_) {
    // Push notification setup must never block the app.
  }

  await FavoritesService.init();

  runApp(const NizikApp());
}

class NizikApp extends StatelessWidget {
  const NizikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: DeepLinkService.instance.navigatorKey,
      scaffoldMessengerKey: NotificationService.scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'نزیک',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF43A047),
        ),
        scaffoldBackgroundColor:
            const Color(0xFFF6F8F6),
        navigationBarTheme:
            const NavigationBarThemeData(
          height: 68,
          labelTextStyle:
              WidgetStatePropertyAll(
            TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      home: const StartupAdGate(
        child: MainShell(),
      ),
    );
  }
}
