import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class NizikShareService {
  NizikShareService._();

  static String shopLink(String slug) =>
      Uri(scheme: 'nizik', host: 'shop', path: '/${slug.trim()}').toString();

  static String marketLink(int id) =>
      Uri(scheme: 'nizik', host: 'market', path: '/$id').toString();

  static String moduleLink(String featureKey, int id) => Uri(
        scheme: 'nizik',
        host: 'module',
        path: '/${featureKey.trim()}/$id',
      ).toString();

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String link,
  }) async {
    final text = '$title\n$link';

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'هاوبەشکردن',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    leading: const Icon(Icons.chat_rounded),
                    title: const Text(
                      'ناردن بە WhatsApp',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      final uri = Uri.https(
                        'wa.me',
                        '/',
                        <String, String>{'text': text},
                      );
                      if (!await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      )) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('WhatsApp نەکرایەوە.')),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    leading: const Icon(Icons.content_copy_rounded),
                    title: const Text(
                      'کۆپیکردنی لینک',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      link,
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('لینک کۆپی کرا ✓')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
