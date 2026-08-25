import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'دەربارە',
          textDirection: TextDirection.rtl,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 20),

            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 52,
                  color: Color(0xFF43A047),
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'نزیک',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'دووکان و خزمەتگوزارییە نزیکەکان بدۆزەرەوە',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'ئەپلیکەیشنی نزیک بۆ ئەوە دروست کراوە کە بەکارهێنەران بتوانن بە ئاسانی دووکان، خواردنگە، کافێ، مارکێت و خزمەتگوزارییە نزیکەکانی خۆیان بدۆزنەوە.',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.8,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'زانیاری',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('my-pro.click'),
                      SizedBox(width: 10),
                      Icon(
                        Icons.language,
                        color: Color(0xFF43A047),
                      ),
                    ],
                  ),

                  SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Version 1.0.0'),
                      SizedBox(width: 10),
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFF43A047),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}