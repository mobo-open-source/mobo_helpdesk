import 'dart:io';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/themes/app_theme.dart';

/// Preference key marking that the get started page has been shown.
const String hasSeenGetStartedKey = 'hasSeenGetStarted';

/// First-launch onboarding page with an auto-playing image carousel.
///
/// [onFinished] is called after the user taps "Get Started"; the caller
/// decides which screen comes next.
class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen> {
  int _currentIndex = 0;

  String _imagePath(String name) => Platform.isIOS
      ? 'assets/images/getstarted/ios$name.jpg'
      : 'assets/images/getstarted/$name.jpg';

  late final List<Map<String, String>> _pages = [
    {
      'image': _imagePath('01'),
      'title': 'Resolve tickets faster.',
      'description':
          'Track, assign and close customer tickets from one place, wherever you are.',
    },
    {
      'image': _imagePath('02'),
      'title': 'Stay on top of every SLA.',
      'description':
          'Monitor SLA policies, team workload and response times to keep customers happy.',
    },
    {
      'image': _imagePath('03'),
      'title': 'Help desk teams, in sync.',
      'description':
          'Organize teams, customers and ratings in one simple helpdesk workspace.',
    },
  ];

  Future<void> _finish() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(hasSeenGetStartedKey, true);
    } catch (_) {}
    if (mounted) widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 400;
    final isWide = size.width >= 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CarouselSlider(
            options: CarouselOptions(
              height: size.height,
              viewportFraction: 1.0,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 4),
              onPageChanged: (index, _) =>
                  setState(() => _currentIndex = index),
            ),
            items: _pages.map((page) {
              return SizedBox(
                width: size.width,
                height: size.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: Image.asset(
                        page['image']!,
                        width: size.width,
                        fit: BoxFit.fitWidth,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.3),
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 600 : 500),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 24 : 40,
                    vertical: isSmall ? 20 : 40,
                  ),
                  child: Column(children: [const Spacer(), _buildContent()]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final page = _pages[_currentIndex];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          page['title']!,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.3,
            letterSpacing: -0.5,
            shadows: const [
              Shadow(
                offset: Offset(0, 2),
                blurRadius: 4,
                color: Colors.black54,
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Text(
          page['description']!,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.8),
            height: 1.6,
            shadows: const [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 2,
                color: Colors.black54,
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _finish,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(
              'Get Started',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        DotsIndicator(
          dotsCount: _pages.length,
          position: _currentIndex.toDouble(),
          decorator: DotsDecorator(
            activeColor: Colors.white,
            color: Colors.white.withValues(alpha: 0.4),
            size: const Size.square(8),
            activeSize: const Size(16, 8),
            activeShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
