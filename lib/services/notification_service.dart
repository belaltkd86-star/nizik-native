import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'location_preference_service.dart';

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

  static final NotificationService instance = NotificationService._();

  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static const String topic = 'nizik_all';
  static const String _areaTopicsKey = 'nizik_notification_area_topics_v1';

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool _locationListenerAttached = false;
  bool _fcmReady = false;
  bool _syncingTopics = false;

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

      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen(
        (newToken) async {
          if (kDebugMode && newToken.isNotEmpty) {
            debugPrint('NIZIK_FCM_TOKEN_REFRESHED=$newToken');
          }
          try {
            await FirebaseMessaging.instance.subscribeToTopic(topic);
            _fcmReady = true;
            await syncRegionalTopics();
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

      _attachLocationListener();

      final canUseFcmNow = await _waitForAppleApnsTokenIfNeeded(messaging);
      if (canUseFcmNow) {
        await messaging.subscribeToTopic(topic);
        _fcmReady = true;
        await syncRegionalTopics();

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

  void _attachLocationListener() {
    if (_locationListenerAttached) return;
    _locationListenerAttached = true;
    LocationPreferenceService.instance.preference.addListener(
      _onLocationPreferenceChanged,
    );
  }

  void _onLocationPreferenceChanged() {
    unawaited(syncRegionalTopics());
  }

  Future<void> syncRegionalTopics() async {
    if (!_fcmReady || _syncingTopics) return;
    _syncingTopics = true;
    try {
      final messaging = FirebaseMessaging.instance;
      final prefs = await SharedPreferences.getInstance();
      final oldTopics =
          (prefs.getStringList(_areaTopicsKey) ?? const <String>[]).toSet();
      final location = LocationPreferenceService.instance.preference.value;
      final nextTopics = <String>{};

      if (location.cityId != null) {
        nextTopics.add('nizik_city_${location.cityId}');
      }
      if (location.regionId != null) {
        nextTopics.add('nizik_region_${location.regionId}');
      }

      for (final oldTopic in oldTopics.difference(nextTopics)) {
        try {
          await messaging.unsubscribeFromTopic(oldTopic);
        } catch (_) {}
      }
      for (final newTopic in nextTopics.difference(oldTopics)) {
        try {
          await messaging.subscribeToTopic(newTopic);
        } catch (_) {}
      }

      await prefs.setStringList(_areaTopicsKey, nextTopics.toList()..sort());

      if (kDebugMode) {
        debugPrint('NIZIK_REGION_TOPICS=${nextTopics.join(',')}');
      }
    } finally {
      _syncingTopics = false;
    }
  }

  Future<bool> _waitForAppleApnsTokenIfNeeded(
    FirebaseMessaging messaging,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return true;
    }

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
        content: Text(text, textDirection: TextDirection.rtl),
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
        content: Text(text, textDirection: TextDirection.rtl),
      ),
    );
  }
}
