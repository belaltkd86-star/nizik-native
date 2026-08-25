# نزیک — App Icon + Native Splash Pack

ئەم ZIP ـە فایلە ڕاستەقینەکانی App Icon و Native Splash ـی Android/iOS ـە، نە تەنها preview.

## ئاسانترین ڕێگا — پێشنیارکراو

### 1) ئەم folder ـە بخەرە ناو project
کۆپی بکە:
assets/branding/

بۆ:
C:\Projects\nizik_native\assets\branding\

### 2) package ـەکان زیاد بکە
لە Terminal:

flutter pub add --dev flutter_launcher_icons
flutter pub add --dev flutter_native_splash

### 3) pubspec.yaml
ناوەڕۆکی `pubspec_branding_snippet.yaml` بخوێنەوە و بەشەکانی
`flutter_launcher_icons:` و `flutter_native_splash:` زیاد بکە بۆ کۆتایی pubspec.yaml.

### 4) فایلەکان دروست بکە
لە Terminal:

dart run flutter_launcher_icons
dart run flutter_native_splash:create

### 5) Run
flutter clean
flutter pub get
flutter run

## ئەنجام
- Android launcher icon = pin + storefront، background ـی سەوزی تاریک.
- Android adaptive icon = background و foreground جیاوازن.
- iOS AppIcon = هەموو size ـە پێویستەکان.
- Native splash = background #043D2E + logo لە ناوەڕاست.

## Direct platform files
ئەگەر نەتهەوێت package بەکاربهێنیت:
- `android/app/src/main/res/` ـی ZIP ـەکە دەتوانیت لە Android project ـەکەت merge بکەیت.
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/` دەتوانیت replace بکەیت.
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/` دەتوانیت replace بکەیت.

تێبینی:
بۆ Android، ئەگەر `colors.xml` ـت پێشتر هەیە، فایلەکە مەسڕەوە؛ تەنها color ـە نوێکان merge بکە.
هەروەها `styles_nizik_snippet.xml` snippet ـە؛ ئەگەر LaunchTheme ـت پێشتر هەیە، item ـەکانی merge بکە.
