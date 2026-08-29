import 'package:flutter/material.dart';

import '../services/report_service.dart';

class ReportSheet {
  static Future<void> show(
    BuildContext context, {
    required String targetType,
    int? targetId,
    String? targetSlug,
    List<String>? reasons,
  }) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'هۆکاری ڕاپۆرتکردن',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                ...(reasons ?? const [
                  'زانیاری هەڵەیە',
                  'فێڵ یان گوماناویە',
                  'ناوەڕۆکی ناشیاوە',
                  'ژمارە یان لینک کار ناکات',
                  'ئایتم فرۆشراوە',
                  'هۆکاری تر',
                ]).map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.flag_outlined),
                    title: Text(item),
                    onTap: () => Navigator.pop(sheetContext, item),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (reason == null || !context.mounted) return;

    final detailsController = TextEditingController();

    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('ڕاپۆرت بنێرە'),
          content: TextField(
            controller: detailsController,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'وردەکاری زیاتر (ئارەزوومەندانە)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('پاشگەزبوونەوە'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ناردن'),
            ),
          ],
        ),
      ),
    );

    if (shouldSend != true || !context.mounted) {
      detailsController.dispose();
      return;
    }

    try {
      await ReportService.submit(
        targetType: targetType,
        targetId: targetId,
        targetSlug: targetSlug,
        reason: reason,
        details: detailsController.text,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'سوپاس، ڕاپۆرتەکەت نێردرا.',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            textDirection: TextDirection.rtl,
          ),
        ),
      );
    } finally {
      detailsController.dispose();
    }
  }
}
