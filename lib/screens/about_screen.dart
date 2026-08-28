import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/contact_service.dart';
import '../services/theme_service.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String _instagramUsername = 'BILAL.REBWAR_';

  Future<void> _openUrl(BuildContext context, Uri uri) async {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('نەتوانرا لینکەکە بکرێتەوە'),
        ),
      );
    }
  }

  Future<void> _openInstagram(BuildContext context) async {
    final appUri = Uri.parse(
      'instagram://user?username=${_instagramUsername.toLowerCase()}',
    );

    if (await canLaunchUrl(appUri)) {
      await _openUrl(context, appUri);
      return;
    }

    await _openUrl(
      context,
      Uri.parse(
        'https://www.instagram.com/${_instagramUsername.toLowerCase()}/',
      ),
    );
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    await _openUrl(
      context,
      NizikContactService.whatsappUri(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const green = Color(0xFF159447);

    return Scaffold(
      appBar: AppBar(
        title: const Text('دەربارەی نزیک'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF159447),
                    Color(0xFF36B565),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 42,
                      color: green,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'نزیک',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'دۆزینەوەی دووکان، خزمەتگوزاری و بازاڕی نزیک بە تۆ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      height: 1.6,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'دەربارە',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: .18),
                ),
              ),
              child: const Text(
                'نزیک ئەپلیکەیشنێکە بۆ ئاسانکردنی دۆزینەوەی شوێن و '
                'خزمەتگوزارییە نزیکەکان، هەروەها بەشی بازاڕ بۆ بینینی '
                'بەرهەم و شتە فرۆشیارییەکان.',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.8,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ڕووکار',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
              child: SwitchListTile.adaptive(
                value: theme.brightness == Brightness.dark,
                onChanged: (value) => ThemeService.instance.setDark(value),
                secondary: Icon(
                  theme.brightness == Brightness.dark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: const Text(
                  'دارک مۆد',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('ڕووکارەکە بۆ شەو و ڕۆژ بگۆڕە'),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'پەیوەندی',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _ContactCard(
              icon: Icons.camera_alt_rounded,
              title: 'Instagram',
              value: _instagramUsername,
              onTap: () => _openInstagram(context),
            ),
            const SizedBox(height: 12),
            _ContactCard(
              icon: Icons.chat_rounded,
              title: 'WhatsApp',
              value: NizikContactService.whatsappDisplay,
              onTap: () => _openWhatsApp(context),
            ),
            const SizedBox(height: 26),
            Center(
              child: Text(
                '© نزیک',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const green = Color(0xFF159447);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: .18),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: green.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.link_rounded,
                  color: green,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
