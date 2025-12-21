import 'package:flutter/material.dart';
// TODO: Consider Jitsi Meet integration for live streaming if needed

class LiveStreamingScreen extends StatefulWidget {
  const LiveStreamingScreen({super.key});

  @override
  State<LiveStreamingScreen> createState() => _LiveStreamingScreenState();
}

class _LiveStreamingScreenState extends State<LiveStreamingScreen> {
  int _selectedTab = 0;
  // TODO: Add participant list when implementing live streaming
  final List<dynamic> _participants = [];
  bool _isHost = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Streams'),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _showCreateStreamDialog(context),
            icon: const Icon(Icons.videocam),
            label: const Text('Go Live'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TabBar(
              controller: TabController(length: 3, vsync: ScrollableState()),
              onTap: (index) => setState(() => _selectedTab = index),
              labelColor: Colors.red,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.red,
              tabs: const [
                Tab(text: 'Live Now'),
                Tab(text: 'Upcoming'),
                Tab(text: 'Past'),
              ],
            ),
          ),
          
          // Content based on selected tab
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _buildLiveNowTab(),
                _buildUpcomingTab(),
                _buildPastTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveNowTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3, // Sample data
      itemBuilder: (context, index) {
        return _StreamCard(
          title: 'Sunday Service ${index + 1}',
          host: 'Pastor John',
          viewerCount: 120 + index * 15,
          isLive: true,
          onTap: () => _joinStream(context, index),
        );
      },
    );
  }

  Widget _buildUpcomingTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return _StreamCard(
          title: 'Upcoming Event ${index + 1}',
          host: 'Speaker Name',
          scheduledTime: DateTime.now().add(Duration(days: index + 1)),
          isLive: false,
          onTap: () => _setReminder(context),
        );
      },
    );
  }

  Widget _buildPastTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10,
      itemBuilder: (context, index) {
        return _StreamCard(
          title: 'Past Stream ${index + 1}',
          host: 'Speaker Name',
          isLive: false,
          hasRecording: true,
          duration: const Duration(hours: 1, minutes: 30),
          onTap: () => _watchReplay(context),
        );
      },
    );
  }

  void _showCreateStreamDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _CreateStreamDialog(),
    );
  }

  Future<void> _joinStream(BuildContext context, int streamId) async {
    // TODO: Implement Jitsi Meet room join for live streaming
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LiveStreamViewer(streamId: streamId),
      ),
    );
  }

  void _setReminder(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminder set!')),
    );
  }

  void _watchReplay(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VideoPlayerWidget()),
    );
  }
}

class _StreamCard extends StatelessWidget {
  final String title;
  final String host;
  final int? viewerCount;
  final bool isLive;
  final DateTime? scheduledTime;
  final bool? hasRecording;
  final Duration? duration;
  final VoidCallback onTap;

  const _StreamCard({
    required this.title,
    required this.host,
    this.viewerCount,
    required this.isLive,
    this.scheduledTime,
    this.hasRecording,
    this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Stack(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: const Icon(Icons.videocam, size: 60, color: Colors.grey),
                ),
                if (isLive)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            
            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    host,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  if (viewerCount != null)
                    Text('$viewerCount viewers'),
                  if (scheduledTime != null)
                    Text('Starts: ${scheduledTime!.toString().split('.')[0]}'),
                  if (duration != null)
                    Text('Duration: ${duration!.inHours}h ${duration!.inMinutes.remainder(60)}m'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateStreamDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Live Stream',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            const TextField(
              decoration: InputDecoration(
                labelText: 'Stream Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            const TextField(
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // TODO: Create stream
                  },
                  child: const Text('Start Stream'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LiveStreamViewer extends StatelessWidget {
  final int streamId;

  const LiveStreamViewer({super.key, required this.streamId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video Player
          Center(
            child: Container(
              color: Colors.grey[900],
              child: const Icon(Icons.play_circle_outline, size: 100, color: Colors.white),
            ),
          ),
          
          // Chat Panel (Right side)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 300,
              color: Colors.black.withOpacity(0.8),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: const Text(
                      'Chat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: 20,
                      itemBuilder: (context, index) {
                        return _ChatMessage(
                          username: 'User ${index + 1}',
                          message: 'This is a sample chat message ${index + 1}',
                        );
                      },
                    ),
                  ),
                  
                  // Message Input
                  Container(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: const TextStyle(color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Top Controls
          Positioned(
            top: 40,
            left: 16,
            right: 316,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.minimize, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage extends StatelessWidget {
  final String username;
  final String message;

  const _ChatMessage({
    required this.username,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            username,
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class VideoPlayerWidget extends StatelessWidget {
  const VideoPlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Video Player')),
    );
  }
}

