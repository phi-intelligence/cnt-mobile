import 'package:flutter/material.dart';

class SidebarNav extends StatelessWidget {
  const SidebarNav({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Logo
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'CNT Media',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Navigation Items
          Expanded(
            child: ListView(
              children: [
                _NavItem(icon: Icons.home, label: 'Home', isActive: true),
                _NavItem(icon: Icons.podcasts, label: 'Podcasts'),
                _NavItem(icon: Icons.music_note, label: 'Music'),
                _NavItem(icon: Icons.video_library, label: 'Live'),
                _NavItem(icon: Icons.people, label: 'Community'),
                _NavItem(icon: Icons.person, label: 'Profile'),
                _NavItem(icon: Icons.favorite, label: 'Favorites'),
                _NavItem(icon: Icons.library_music, label: 'Library'),
                _NavItem(icon: Icons.add_box, label: 'Create'),
                _NavItem(icon: Icons.settings, label: 'Settings'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _NavItem({
    required this.icon,
    required this.label,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: isActive,
      selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      onTap: () {
        // TODO: Navigate to screen
      },
    );
  }
}

