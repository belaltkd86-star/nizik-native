// Firebase options for Nizik Android + iOS.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase web options are not configured for Nizik.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'Firebase is not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC3d0EgzsIkJMhEv0h1ybXt302rD6YOZa4',
    appId: '1:1042194163923:android:f2cd45140271a039658c26',
    messagingSenderId: '1042194163923',
    projectId: 'nizik-a26f7',
    storageBucket: 'nizik-a26f7.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAQjHNjOCZip_uc6yWBC7-LHOQju_AJId0',
    appId: '1:1042194163923:ios:905b2d170841c426658c26',
    messagingSenderId: '1042194163923',
    projectId: 'nizik-a26f7',
    storageBucket: 'nizik-a26f7.firebasestorage.app',
    iosBundleId: 'com.nizik.nizikNative',
  );
}
