import 'package:flutter/material.dart';
import '../../widgets/voice/voice_bubble.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Voice Chat Modal - Full-screen modal for voice chat
/// TODO: Consider Jitsi Meet integration for voice chat functionality
class VoiceChatModal extends StatefulWidget {
  const VoiceChatModal({super.key});

  @override
  State<VoiceChatModal> createState() => _VoiceChatModalState();
}

class _VoiceChatModalState extends State<VoiceChatModal> {
  // TODO: Add Jitsi room connection if implementing voice chat
  bool _isConnected = false;
  bool _isMicrophoneEnabled = false;
  bool _isListening = false;
  String _statusMessage = 'Connecting to AI Assistant...';
  final List<Map<String, String>> _messages = [];

  @override
  void initState() {
    super.initState();
    _connectToVoiceChat();
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  Future<void> _connectToVoiceChat() async {
    try {
      setState(() {
        _statusMessage = 'Connecting...';
      });

      // Generate room name and user ID for future voice chat integration
      // final roomName = 'ai-chat-${DateTime.now().millisecondsSinceEpoch}';
      // final userId = 'user-${DateTime.now().millisecondsSinceEpoch}';
      
      // Simulate connection delay
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _statusMessage = 'Connecting to voice chat server...';
      });
      
      // Simulate successful connection
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _statusMessage = 'Connected to AI Assistant';
        _isConnected = true;
        _isMicrophoneEnabled = true;
        _isListening = true;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Connection failed: ${e.toString()}';
      });
    }
  }


  Future<void> _toggleMicrophone() async {
    setState(() {
      _isMicrophoneEnabled = !_isMicrophoneEnabled;
      _isListening = _isMicrophoneEnabled;
    });

    if (_isMicrophoneEnabled && _messages.isEmpty) {
      // Add welcome message
      setState(() {
        _messages.add({
          'type': 'ai',
          'text': 'Hello! I\'m your AI assistant. How can I help you today?',
        });
      });
    }
    
    // TODO: Implement microphone toggle with voice chat service
    // await _room!.localParticipant.setMicrophoneEnabled(_isMicrophoneEnabled);
  }

  Future<void> _disconnect() async {
    // if (_room != null) {
    //   await _room!.disconnect();
    //   _room = null;
    // }
    setState(() {
      _isConnected = false;
      _isMicrophoneEnabled = false;
      _isListening = false;
    });
  }

  void _handleClose() {
    _disconnect();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryMain.withOpacity(0.9),
              AppColors.accentMain.withOpacity(0.9),
              Colors.black,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(AppSpacing.large),
                child: Row(
                  children: [
                    const Icon(
                      Icons.smart_toy,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Text(
                      'AI Assistant',
                      style: AppTypography.heading3.copyWith(color: Colors.white),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _handleClose,
                    ),
                  ],
                ),
              ),

              // Status indicator
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.large),
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.small,
                  horizontal: AppSpacing.medium,
                ),
                decoration: BoxDecoration(
                  color: _isConnected ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isConnected ? Colors.green : Colors.orange,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isConnected ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Voice bubble (animated)
              VoiceBubble(
                isActive: _isListening,
                label: _isListening ? 'Listening...' : 'Tap to speak',
                onPressed: _toggleMicrophone,
              ),

              const Spacer(),

              // Conversation history
              if (_messages.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.large),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message['type'] == 'user';
                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.medium),
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.medium),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isUser 
                              ? Colors.blue.withOpacity(0.3)
                              : Colors.green.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            message['text'] ?? '',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Controls
              Container(
                padding: const EdgeInsets.all(AppSpacing.large),
                child: Column(
                  children: [
                    // Mic button
                    GestureDetector(
                      onTap: _toggleMicrophone,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isMicrophoneEnabled ? Colors.red : Colors.blue,
                          boxShadow: [
                            BoxShadow(
                              color: (_isMicrophoneEnabled ? Colors.red : Colors.blue).withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    Text(
                      _isMicrophoneEnabled ? 'Listening...' : 'Tap to start',
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

