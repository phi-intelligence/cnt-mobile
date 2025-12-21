import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/audio_player_provider.dart';
import '../../services/download_service.dart';
import '../../models/content_item.dart';
import '../../widgets/shared/loading_shimmer.dart';
import '../../widgets/shared/empty_state.dart';
import '../../widgets/mobile/content_card_mobile.dart';

class LibraryScreenMobile extends StatefulWidget {
  const LibraryScreenMobile({super.key});

  @override
  State<LibraryScreenMobile> createState() => _LibraryScreenMobileState();
}

class _LibraryScreenMobileState extends State<LibraryScreenMobile> {
  int _selectedIndex = 0;
  final List<String> _sections = ['Downloaded', 'Playlists', 'Favorites'];
  final DownloadService _downloadService = DownloadService();
  List<Map<String, dynamic>> _downloads = [];
  bool _isLoadingDownloads = false;

  @override
  void initState() {
    super.initState();
    print('✅ LibraryScreenMobile initState');
    _loadDownloads();
    // Fetch playlists and favorites on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        context.read<PlaylistProvider>().fetchPlaylists();
        context.read<FavoritesProvider>().fetchFavorites();
      } catch (e) {
        print('❌ LibraryScreenMobile: Error fetching playlists/favorites: $e');
      }
    });
  }

  Future<void> _loadDownloads() async {
    try {
      if (mounted) {
        setState(() => _isLoadingDownloads = true);
      }
      final downloads = await _downloadService.getDownloads();
      if (mounted) {
        setState(() {
          _downloads = downloads;
          _isLoadingDownloads = false;
        });
      }
    } catch (e) {
      print('❌ LibraryScreenMobile: Error loading downloads: $e');
      if (mounted) {
        setState(() => _isLoadingDownloads = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        title: const Text('Library'),
      ),
      body: Column(
        children: [
          // Segmented Control
          Padding(
            padding: EdgeInsets.all(AppSpacing.medium),
            child: Row(
              children: List.generate(_sections.length, (index) {
                final isSelected = index == _selectedIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.small),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryMain : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                      ),
                      child: Text(
                        _sections[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDownloadedSection();
      case 1:
        return _buildPlaylistsSection();
      case 2:
        return _buildFavoritesSection();
      default:
        return const SizedBox();
    }
  }

  Widget _buildDownloadedSection() {
    if (_isLoadingDownloads) {
      return ListView.builder(
        padding: EdgeInsets.all(AppSpacing.medium),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.medium),
            child: const LoadingShimmer(width: double.infinity, height: 100),
          );
        },
      );
    }

    if (_downloads.isEmpty) {
      return const EmptyState(
        icon: Icons.download_outlined,
        title: 'No Downloads',
        message: 'Download content to listen offline',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDownloads,
      child: ListView.builder(
        padding: EdgeInsets.all(AppSpacing.medium),
        itemCount: _downloads.length,
        itemBuilder: (context, index) {
          final download = _downloads[index];
          final item = ContentItem(
            id: download['id'],
            title: download['title'],
            creator: download['creator'] ?? 'Unknown',
            description: '',
            coverImage: download['cover_image'],
            audioUrl: download['local_path'],
            duration: download['duration'] != null
                ? Duration(seconds: download['duration'])
                : null,
            category: download['category'] ?? 'Downloaded',
            createdAt: download['created_at'] != null
                ? DateTime.parse(download['created_at'])
                : DateTime.now(),
          );

          return Card(
            margin: EdgeInsets.only(bottom: AppSpacing.medium),
            child: ListTile(
              leading: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.music_note,
                  color: AppColors.primaryMain,
                ),
              ),
              title: Text(download['title']),
              subtitle: Text(download['creator'] ?? 'Unknown'),
              trailing: IconButton(
                icon: const Icon(Icons.play_circle_outline),
                onPressed: () {
                  context.read<AudioPlayerState>().playContent(item);
                },
              ),
              onTap: () {
                context.read<AudioPlayerState>().playContent(item);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistsSection() {
    return Consumer<PlaylistProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return ListView.builder(
            padding: EdgeInsets.all(AppSpacing.medium),
            itemCount: 3,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.medium),
                child: const LoadingShimmer(width: double.infinity, height: 100),
              );
            },
          );
        }

        if (provider.playlists.isEmpty) {
          return Column(
            children: [
              const EmptyState(
                icon: Icons.queue_music_outlined,
                title: 'No Playlists',
                message: 'Create your first playlist',
              ),
              Padding(
                padding: EdgeInsets.all(AppSpacing.large),
                child: ElevatedButton.icon(
                  onPressed: () => _showCreatePlaylistDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Playlist'),
                ),
              ),
            ],
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(AppSpacing.medium),
          itemCount: provider.playlists.length,
          itemBuilder: (context, index) {
            final playlist = provider.playlists[index];
            return Card(
              margin: EdgeInsets.only(bottom: AppSpacing.medium),
              child: ListTile(
                leading: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primaryMain.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.queue_music,
                    color: AppColors.primaryMain,
                  ),
                ),
                title: Text(playlist['name'] ?? 'Untitled Playlist'),
                subtitle: Text(
                  '${playlist['item_count'] ?? 0} items',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Navigate to playlist detail
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Playlist detail coming soon')),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFavoritesSection() {
    return Consumer<FavoritesProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return ListView.builder(
            padding: EdgeInsets.all(AppSpacing.medium),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.medium),
                child: const LoadingShimmer(width: double.infinity, height: 100),
              );
            },
          );
        }

        if (provider.favorites.isEmpty) {
          return const EmptyState(
            icon: Icons.favorite_border,
            title: 'No Favorites',
            message: 'Like content to see it here',
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(AppSpacing.medium),
          itemCount: provider.favorites.length,
          itemBuilder: (context, index) {
            final item = provider.favorites[index];
            return Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.medium),
              child: ContentCardMobile(
                item: item,
                onTap: () {
                  context.read<AudioPlayerState>().playContent(item);
                },
                onPlay: () {
                  context.read<AudioPlayerState>().playContent(item);
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Playlist'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Playlist Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                final success = await context.read<PlaylistProvider>().createPlaylist(
                  name: nameController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Playlist created!'
                            : 'Failed to create playlist',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
