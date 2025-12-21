import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/event.dart';
import '../../providers/event_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/media_utils.dart';

class EventDetailScreen extends StatefulWidget {
  final int eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _showAttendees = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEvent();
    });
  }

  Future<void> _loadEvent() async {
    final provider = context.read<EventProvider>();
    await provider.fetchEventDetails(widget.eventId);
  }

  Future<void> _handleJoinEvent() async {
    final provider = context.read<EventProvider>();
    final success = await provider.joinEvent(widget.eventId);
    
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Join request sent! Waiting for host approval.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error!),
          backgroundColor: AppColors.errorMain,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _handleLeaveEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Event?'),
        content: const Text('Are you sure you want to leave this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorMain),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    final provider = context.read<EventProvider>();
    final success = await provider.leaveEvent(widget.eventId);
    
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You have left the event'),
          backgroundColor: AppColors.warmBrown,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: Consumer<EventProvider>(
        builder: (context, provider, _) {
          final event = provider.selectedEvent;
          
          if (provider.isLoading && event == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.warmBrown),
            );
          }
          
          if (event == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    'Event not found',
                    style: AppTypography.heading4.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }
          
          final authProvider = context.read<AuthProvider>();
          final currentUserId = authProvider.user?['id'] as int?;
          final isHost = event.hostId == currentUserId;
          
          return CustomScrollView(
            slivers: [
              // App Bar with cover image
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: AppColors.warmBrown,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: event.coverImage != null && event.coverImage!.isNotEmpty
                      ? Image.network(
                          resolveMediaUrl(event.coverImage!) ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.warmBrown,
                            child: const Icon(Icons.event, size: 64, color: Colors.white38),
                          ),
                        )
                      : Container(
                          color: AppColors.warmBrown,
                          child: const Icon(Icons.event, size: 64, color: Colors.white38),
                        ),
                ),
                actions: [
                  if (isHost)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (value) async {
                        if (value == 'delete') {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Cancel Event?'),
                              content: const Text('Are you sure you want to cancel this event?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('No'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(foregroundColor: AppColors.errorMain),
                                  child: const Text('Cancel Event'),
                                ),
                              ],
                            ),
                          );
                          
                          if (confirmed == true) {
                            final success = await provider.deleteEvent(event.id);
                            if (success && mounted) {
                              Navigator.pop(context);
                            }
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.cancel, color: AppColors.errorMain),
                              SizedBox(width: 8),
                              Text('Cancel Event'),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              
              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.medium),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Status
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: AppTypography.heading2.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (event.isPast)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Text(
                                'Past Event',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: AppSpacing.medium),
                      
                      // Date & Time Card
                      _buildInfoCard(
                        icon: Icons.calendar_today,
                        title: 'Date & Time',
                        content: DateFormat('EEEE, MMMM d, yyyy').format(event.eventDate) +
                            '\n' +
                            DateFormat('h:mm a').format(event.eventDate),
                      ),
                      
                      const SizedBox(height: AppSpacing.small),
                      
                      // Location Card
                      if (event.location != null)
                        _buildInfoCard(
                          icon: Icons.location_on,
                          title: 'Location',
                          content: event.location!,
                        ),
                      
                      // Mini-map if coordinates exist
                      if (event.hasCoordinates) ...[
                        const SizedBox(height: AppSpacing.small),
                        _buildMiniMap(event),
                      ],
                      
                      const SizedBox(height: AppSpacing.small),
                      
                      // Host Card
                      _buildHostCard(event),
                      
                      const SizedBox(height: AppSpacing.medium),
                      
                      // Description
                      if (event.description != null) ...[
                        Text(
                          'About',
                          style: AppTypography.heading4.copyWith(
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(AppSpacing.medium),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Text(
                            event.description!,
                            style: AppTypography.body.copyWith(
                              color: AppColors.primaryDark,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.medium),
                      ],
                      
                      // Attendees Section
                      _buildAttendeesSection(event, isHost),
                      
                      const SizedBox(height: 100), // Space for bottom button
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Consumer<EventProvider>(
        builder: (context, provider, _) {
          final event = provider.selectedEvent;
          if (event == null || event.isPast) return const SizedBox.shrink();
          
          final authProvider = context.read<AuthProvider>();
          final currentUserId = authProvider.user?['id'] as int?;
          final isHost = event.hostId == currentUserId;
          
          if (isHost) return const SizedBox.shrink();
          
          return Container(
            padding: EdgeInsets.all(AppSpacing.medium),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: event.isAttending
                  ? Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: event.myAttendanceStatus == 'approved'
                                  ? Colors.green.withOpacity(0.1)
                                  : AppColors.warningMain.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  event.myAttendanceStatus == 'approved'
                                      ? Icons.check_circle
                                      : Icons.hourglass_empty,
                                  color: event.myAttendanceStatus == 'approved'
                                      ? Colors.green
                                      : AppColors.warningMain,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  event.myAttendanceStatus == 'approved'
                                      ? 'You\'re attending'
                                      : 'Request pending',
                                  style: TextStyle(
                                    color: event.myAttendanceStatus == 'approved'
                                        ? Colors.green
                                        : AppColors.warningMain,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: _handleLeaveEvent,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.errorMain,
                          ),
                          child: const Text('Leave'),
                        ),
                      ],
                    )
                  : ElevatedButton(
                      onPressed: event.isFull ? null : _handleJoinEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warmBrown,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        event.isFull ? 'Event Full' : 'Request to Join',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warmBrown.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.warmBrown),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  content,
                  style: AppTypography.body.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMap(EventModel event) {
    final location = LatLng(event.latitude!, event.longitude!);
    
    return GestureDetector(
      onTap: () => _openInMapsApp(event),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Map
              AbsorbPointer(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: location,
                    initialZoom: 15.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.christtabernacle.cntmedia',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: location,
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.location_pin,
                            color: AppColors.warmBrown,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Overlay with "Open in Maps" hint
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: AppColors.warmBrown,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Open in Maps',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.warmBrown,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openInMapsApp(EventModel event) async {
    if (!event.hasCoordinates) return;
    
    final lat = event.latitude!;
    final lng = event.longitude!;
    final label = Uri.encodeComponent(event.location ?? event.title);
    
    // Try Google Maps first, then Apple Maps, then browser
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    final appleMapsUrl = Uri.parse('https://maps.apple.com/?q=$label&ll=$lat,$lng');
    
    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(appleMapsUrl)) {
        await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to browser
        await launchUrl(googleMapsUrl, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open maps: $e'),
            backgroundColor: AppColors.errorMain,
          ),
        );
      }
    }
  }

  Widget _buildHostCard(EventModel event) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.medium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.warmBrown.withOpacity(0.2),
            backgroundImage: event.host?.avatar != null && event.host!.avatar!.isNotEmpty
                ? NetworkImage(resolveMediaUrl(event.host!.avatar!) ?? '')
                : null,
            child: event.host?.avatar == null || event.host!.avatar!.isEmpty
                ? Icon(Icons.person, color: AppColors.warmBrown)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hosted by',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  event.host?.name ?? 'Unknown',
                  style: AppTypography.body.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendeesSection(EventModel event, bool isHost) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Attendees (${event.attendeesCount}${event.maxAttendees > 0 ? '/${event.maxAttendees}' : ''})',
              style: AppTypography.heading4.copyWith(
                color: AppColors.primaryDark,
              ),
            ),
            if (isHost)
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAttendees = !_showAttendees;
                  });
                  if (_showAttendees) {
                    context.read<EventProvider>().fetchEventAttendees(widget.eventId);
                  }
                },
                child: Text(
                  _showAttendees ? 'Hide' : 'Manage',
                  style: TextStyle(color: AppColors.warmBrown),
                ),
              ),
          ],
        ),
        
        if (_showAttendees && isHost)
          Consumer<EventProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: AppColors.warmBrown),
                  ),
                );
              }
              
              if (provider.selectedEventAttendees.isEmpty) {
                return Container(
                  padding: EdgeInsets.all(AppSpacing.medium),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'No attendees yet',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }
              
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.selectedEventAttendees.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final attendee = provider.selectedEventAttendees[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.warmBrown.withOpacity(0.2),
                        backgroundImage: attendee.user?.avatar != null && attendee.user!.avatar!.isNotEmpty
                            ? NetworkImage(resolveMediaUrl(attendee.user!.avatar!) ?? '')
                            : null,
                        child: attendee.user?.avatar == null || attendee.user!.avatar!.isEmpty
                            ? Icon(Icons.person, color: AppColors.warmBrown, size: 20)
                            : null,
                      ),
                      title: Text(attendee.user?.name ?? 'User'),
                      subtitle: Text(
                        attendee.status.toUpperCase(),
                        style: TextStyle(
                          color: attendee.status == 'approved'
                              ? Colors.green
                              : attendee.status == 'pending'
                                  ? AppColors.warningMain
                                  : AppColors.errorMain,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: attendee.status == 'pending'
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle, color: Colors.green),
                                  onPressed: () => provider.updateAttendeeStatus(
                                    widget.eventId,
                                    attendee.userId,
                                    'approved',
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.cancel, color: AppColors.errorMain),
                                  onPressed: () => provider.updateAttendeeStatus(
                                    widget.eventId,
                                    attendee.userId,
                                    'rejected',
                                  ),
                                ),
                              ],
                            )
                          : null,
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}

