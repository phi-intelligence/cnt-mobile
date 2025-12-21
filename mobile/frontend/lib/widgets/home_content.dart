import 'package:flutter/material.dart';
import 'content_section.dart';
import 'voice_bubble.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Section with Voice Bubble
            Container(
              height: 300,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Welcome to CNT Media',
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Your Christian media platform',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    top: 20,
                    right: 20,
                    child: VoiceBubble(),
                  ),
                ],
              ),
            ),
            
            // Content Sections
            const ContentSection(
              title: 'Recently Played',
              items: [],
            ),
            const ContentSection(
              title: 'New Podcasts',
              items: [],
            ),
            const ContentSection(
              title: 'Music',
              items: [],
            ),
            const ContentSection(
              title: 'Bible Stories',
              items: [],
            ),
          ],
        ),
      ),
    );
  }
}

