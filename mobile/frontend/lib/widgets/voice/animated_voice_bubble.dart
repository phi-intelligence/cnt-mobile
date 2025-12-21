import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Animated Voice Bubble with pulsing waves
/// Used in the AI Voice Assistant screen during conversations
class AnimatedVoiceBubble extends StatefulWidget {
  final bool isActive;
  final String state; // listening, speaking, thinking, idle
  final double size;

  const AnimatedVoiceBubble({
    super.key,
    this.isActive = false,
    this.state = 'idle',
    this.size = 200,
  });

  @override
  State<AnimatedVoiceBubble> createState() => _AnimatedVoiceBubbleState();
}

class _AnimatedVoiceBubbleState extends State<AnimatedVoiceBubble>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _barsController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for the main bubble
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Wave animation for ripples
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _waveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _waveController, curve: Curves.easeOut),
    );
    
    // Bars animation for soundbar
    _barsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _updateAnimations();
  }

  @override
  void didUpdateWidget(AnimatedVoiceBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state || oldWidget.isActive != widget.isActive) {
      _updateAnimations();
    }
  }

  void _updateAnimations() {
    if (widget.isActive || widget.state == 'speaking' || widget.state == 'listening') {
      _pulseController.repeat(reverse: true);
      _waveController.repeat();
      _barsController.repeat(reverse: true);
    } else if (widget.state == 'thinking') {
      _pulseController.repeat(reverse: true);
      _waveController.stop();
      _barsController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
      _waveController.stop();
      _waveController.value = 0;
      _barsController.stop();
      _barsController.value = 0.5;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _barsController.dispose();
    super.dispose();
  }

  Color get _stateColor {
    switch (widget.state.toLowerCase()) {
      case 'listening':
        return AppColors.warmBrown;
      case 'speaking':
        return AppColors.warmBrown;
      case 'thinking':
        return AppColors.warmBrown.withOpacity(0.7);
      default:
        return AppColors.warmBrown;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size + 80,
      height: widget.size + 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated wave rings
          if (widget.isActive || widget.state == 'speaking' || widget.state == 'listening')
            ...List.generate(3, (index) => _buildWaveRing(index)),
          
          // Main bubble with pulse
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isActive ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: _stateColor.withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: _buildAnimatedSoundBars(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWaveRing(int index) {
    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        final delay = index * 0.3;
        final progress = (_waveAnimation.value + delay) % 1.0;
        final scale = 1.0 + (progress * 0.5);
        final opacity = (1.0 - progress).clamp(0.0, 0.4);
        
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _stateColor.withOpacity(opacity),
                width: 3,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedSoundBars() {
    return AnimatedBuilder(
      animation: _barsController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(5, (index) {
            final baseHeight = widget.size * 0.15;
            final maxHeight = widget.size * 0.35;
            
            double height;
            if (widget.isActive || widget.state == 'speaking' || widget.state == 'listening') {
              // Animated heights with phase offset
              final phase = (_barsController.value + index * 0.15) % 1.0;
              final wave = sin(phase * pi);
              height = baseHeight + (maxHeight - baseHeight) * wave;
            } else if (widget.state == 'thinking') {
              // Gentle pulse
              final phase = (_barsController.value + index * 0.1) % 1.0;
              final wave = sin(phase * pi) * 0.3;
              height = baseHeight + (maxHeight - baseHeight) * 0.3 + wave * 10;
            } else {
              // Static bars
              final staticHeights = [0.6, 0.8, 1.0, 0.8, 0.6];
              height = baseHeight + (maxHeight - baseHeight) * staticHeights[index] * 0.5;
            }
            
            return Container(
              width: widget.size * 0.06,
              height: height,
              margin: EdgeInsets.symmetric(horizontal: widget.size * 0.02),
              decoration: BoxDecoration(
                color: _stateColor,
                borderRadius: BorderRadius.circular(widget.size * 0.03),
              ),
            );
          }),
        );
      },
    );
  }
}
