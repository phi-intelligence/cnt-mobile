import 'package:flutter/material.dart';
import '../widgets/sidebar_nav.dart';
import '../widgets/home_content.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          const SidebarNav(),
          
          // Main Content
          Expanded(
            child: const HomeContent(),
          ),
        ],
      ),
    );
  }
}

