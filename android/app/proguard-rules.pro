# Nizik release hardening
#
# Flutter and Firebase dependencies ship their own consumer ProGuard/R8 rules.
# Keep this file intentionally minimal to reduce the risk of breaking plugins.
#
# Add plugin-specific keep rules here only if a release build reports a
# missing-class / reflection problem.
