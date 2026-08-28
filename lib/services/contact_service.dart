import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NizikContactService {
  NizikContactService._();

  static const String whatsappNumber = '9647751011001';
  static const String whatsappDisplay = '+964 775 101 1001';

  static Uri whatsappUri({String? message}) {
    return Uri.https(
      'wa.me',
      '/$whatsappNumber',
      message == null || message.trim().isEmpty
          ? null
          : <String, String>{'text': message.trim()},
    );
  }

  static Future<void> openWhatsApp(
    BuildContext context, {
    String? message,
  }) async {
    final opened = await launchUrl(
      whatsappUri(message: message),
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'نەتوانرا WhatsApp بکرێتەوە.',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    }
  }

  static Future<void> request(
    BuildContext context, {
    required String section,
    String? itemTitle,
    String? extra,
  }) async {
    final buffer = StringBuffer()
      ..writeln('سڵاو، داواکارییەکم هەیە لە ئەپی نزیک.')
      ..writeln('بەش: $section');

    if (itemTitle != null && itemTitle.trim().isNotEmpty) {
      buffer.writeln('سەبارەت بە: ${itemTitle.trim()}');
    }
    if (extra != null && extra.trim().isNotEmpty) {
      buffer.writeln(extra.trim());
    }

    await openWhatsApp(context, message: buffer.toString().trim());
  }
}
