import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> nizikFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
      NotificationService._();

  static final GlobalKey<ScaffoldMessengerState>
      scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  static const String topic = 'nizik_all';

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  Future<void> initialize() async {
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (kDebugMode) {
        debugPrint(
          'NIZIK_NOTIFICATION_PERMISSION=${settings.authorizationStatus}',
        );
      }

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Register listeners before requesting the initial FCM token.
      // This keeps Android behavior unchanged and lets iOS recover naturally
      // when APNs/FCM finishes creating a token after app startup.
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen(
        (newToken) async {
          if (kDebugMode && newToken.isNotEmpty) {
            debugPrint('NIZIK_FCM_TOKEN_REFRESHED=$newToken');
          }
          try {
            await FirebaseMessaging.instance.subscribeToTopic(topic);
          } catch (error) {
            if (kDebugMode) {
              debugPrint('NIZIK_TOPIC_RESUBSCRIBE_ERROR=$error');
            }
          }
        },
        onError: (Object error) {
          if (kDebugMode) {
            debugPrint('NIZIK_FCM_TOKEN_REFRESH_ERROR=$error');
          }
        },
      );

      await _foregroundSubscription?.cancel();
      _foregroundSubscription =
          FirebaseMessaging.onMessage.listen(_showForegroundMessage);

      await _openedSubscription?.cancel();
      _openedSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

      final canUseFcmNow = await _waitForAppleApnsTokenIfNeeded(messaging);

      if (canUseFcmNow) {
        // All Nizik users receive general app notifications through this topic.
        await messaging.subscribeToTopic(topic);

        // Printed only in debug builds so a Firebase Console test can target
        // this exact emulator/device. Release builds never print the token.
        final token = await messaging.getToken();
        if (kDebugMode && token != null && token.isNotEmpty) {
          debugPrint('NIZIK_FCM_TOKEN=$token');
        }
      } else if (kDebugMode) {
        debugPrint(
          'NIZIK_APNS_TOKEN_NOT_READY: initial FCM registration deferred.',
        );
      }

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleOpenedMessage(initialMessage);
        });
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('NIZIK_NOTIFICATION_INIT_ERROR=$error');
      }
      // Notifications must never block normal app startup.
    }
  }

  Future<bool> _waitForAppleApnsTokenIfNeeded(
    FirebaseMessaging messaging,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return true;
    }

    // On iOS, Firebase requires the APNs token to exist before FCM API calls
    // such as getToken()/topic subscription. Give the OS a short bounded
    // window to deliver it; never stall app startup indefinitely.
    for (var attempt = 0; attempt < 20; attempt++) {
      final apnsToken = await messaging.getAPNSToken();
      if (apnsToken != null && apnsToken.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('NIZIK_APNS_TOKEN_READY=true');
        }
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    return false;
  }

  void _showForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title?.trim() ?? '';
    final body = notification?.body?.trim() ?? '';

    if (title.isEmpty && body.isEmpty) return;

    final text = [
      if (title.isNotEmpty) title,
      if (body.isNotEmpty) body,
    ].join('\n');

    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: Text(
          text,
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title?.trim() ?? '';
    final body = notification?.body?.trim() ?? '';

    if (title.isEmpty && body.isEmpty) return;

    final text = [
      if (title.isNotEmpty) title,
      if (body.isNotEmpty) body,
    ].join('\n');

    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: Text(
          text,
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }
}
