import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/location_setup_gate.dart';
import 'screens/main_shell.dart';
import 'screens/startup_ad_gate.dart';
import 'services/deep_link_service.dart';
import 'services/favorites_service.dart';
import 'services/location_preference_service.dart';
import 'services/notification_service.dart';
import 'services/shop_distance_service.dart';
import 'services/theme_service.dart';
import 'theme/nizik_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  DeepLinkService.instance.start();

  // Local state is ready before push registration so city/region topics are
  // correct from the first FCM subscription.
  await ThemeService.instance.init();
  await FavoritesService.init();
  await LocationPreferenceService.instance.init();
  await ShopDistanceService.instance.init();

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

  runApp(const NizikApp());
}

class NizikApp extends StatelessWidget {
  const NizikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          navigatorKey: DeepLinkService.instance.navigatorKey,
          scaffoldMessengerKey: NotificationService.scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          title: 'نزیک',
          theme: NizikTheme.light(),
          darkTheme: NizikTheme.dark(),
          themeMode: mode,
          home: const LocationSetupGate(
            child: StartupAdGate(
              child: MainShell(),
            ),
          ),
        );
      },
    );
  }
}
