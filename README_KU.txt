نزیک - پەکی کۆتایی
==================

ئەم پەکە بۆ پڕۆژەی C:\Projects\nizik_native ئامادە کراوە.

چی چاک کراوە:
- ناوی iPhone = نزیک
- iOS Location Permission
- LocationService بۆ denied / deniedForever / Location Services
- pubspec پاک و ئامادەی icon + splash
- iOS icon alpha removal
- Android build config پارێزراوە
- Finalizer تەنها AndroidManifest ـی هەبوو دەستکاری دەکات و deep link ـەکان ناسڕێتەوە
- INTERNET + COARSE/FINE LOCATION permission دڵنیادەکاتەوە
- ناوی Android = نزیک

بەکارهێنان:
1) ناوەڕۆکی ZIP ـەکە بخەرە ناو:
   C:\Projects\nizik_native
   و Replace بکە.

2) دوو-کلیک لە:
   FINALIZE_NIZIK.cmd

3) کاتێک بە سەرکەوتوویی تەواو بوو، دوو-کلیک لە:
   BUILD_NIZIK_ANDROID.cmd

APK ـی کۆتایی:
C:\Projects\nizik_native\build\app\outputs\flutter-apk\app-release.apk

تێبینی گرنگ:
build.gradle.kts هێشتا release APK بە debug signing دروست دەکات بۆ تاقیکردنەوە/دامەزراندن.
بۆ Google Play پێویستە release keystore ـی تایبەت دروست بکرێت؛ ئەوە قۆناغێکی جیاوازە چونکە key ـەکە دەبێت بە پارێزراوی بپارێزرێت.

iPhone:
Info.plist ئامادەی When-In-Use Location ـە. Build و signing ـی iPhone لە Windows بە Xcode ناکرێت؛ Codemagic/Mac + Apple signing پێویستە بۆ IPA ـی دامەزرێنراو.
