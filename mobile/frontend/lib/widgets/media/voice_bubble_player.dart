import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_animations.dart';

/// Voice Bubble for Podcast Player
/// Large animated voice bubble with sound visualization
class VoiceBubblePlayer extends StatefulWidget {
  final bool isPlaying;
  final double size;
  final Color? backgroundColor;
  final Color? accentColor;

  const VoiceBubblePlayer({
    super.key,
    required this.isPlaying,
    this.size = 200,
    this.backgroundColor,
    this.accentColor,
  });

  @override
  State<VoiceBubblePlayer> createState() => _VoiceBubblePlayerState();
}

class _VoiceBubblePlayerState extends State<VoiceBubblePlayer>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _soundbarController;
  late AnimationController _pulseController;
  
  late Animation<double> _waveScaleAnimation;
  late Animation<double> _waveOpacityAnimation;
  late Animation<double> _bubbleScaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Wave animation for outer rings
    _waveController = AnimationController(
      vsync: this,
      duration: AppAnimations.voiceWaveDuration,
    );
    
    // Soundbar animation for 5 bars
    _soundbarController = AnimationController(
      vsync: this,
      duration: AppAnimations.soundbarLoopDuration,
    );

    // Pulse animation for bubble scale
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Wave animations
    _waveScaleAnimation = Tween<double>(
      begin: AppAnimations.waveScaleStart,
      end: AppAnimations.waveScaleEnd,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: AppAnimations.voiceBubbleCurve,
    ));

    _waveOpacityAnimation = Tween<double>(
      begin: AppAnimations.waveOpacityStart,
      end: AppAnimations.waveOpacityEnd,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: AppAnimations.voiceBubbleCurve,
    ));

    // Bubble pulse when playing
    _bubbleScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _startAnimations();
  }

  void _startAnimations() {
    if (widget.isPlaying) {
      _waveController.repeat();
      _soundbarController.repeat();
      _pulseController.repeat(reverse: true);
    } else {
      _waveController.stop();
      _soundbarController.repeat(); // Keep subtle animation
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void didUpdateWidget(VoiceBubblePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      _startAnimations();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _soundbarController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer wave rings (only when playing)
        if (widget.isPlaying)
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (widget.accentColor ?? AppColors.accentMain)
                        .withOpacity(_waveOpacityAnimation.value),
                    width: 3,
                  ),
                ),
                transform: Matrix4.identity()
                  ..scale(_waveScaleAnimation.value),
              );
            },
          ),
        
        // Main bubble
        AnimatedBuilder(
          animation: _bubbleScaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.isPlaying ? _bubbleScaleAnimation.value : 1.0,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.backgroundColor ?? Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: (widget.accentColor ?? AppColors.accentMain).withOpacity(0.3),
                      offset: const Offset(0, 8),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Microphone icon (only when paused)
                    if (!widget.isPlaying) ...[
                      Icon(
                        Icons.podcasts,
                        size: widget.size * 0.15,
                        color: widget.accentColor ?? AppColors.accentMain,
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // 5-bar sound visualization
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return _SoundBar(
                          index: index,
                          controller: _soundbarController,
                          isActive: widget.isPlaying,
                          color: widget.accentColor ?? AppColors.accentMain,
                        );
                      }),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Individual sound bar with unique animation pattern
class _SoundBar extends StatelessWidget {
  final int index;
  final AnimationController controller;
  final bool isActive;
  final Color color;

  const _SoundBar({
    required this.index,
    required this.controller,
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    late Animation<double> scaleAnimation;
    
    if (!isActive) {
      // Subtle idle animation when paused
      scaleAnimation = Tween(begin: 0.3, end: 0.5)
          .animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    } else {
      // Active animation when playing - each bar has unique pattern
      switch (index) {
        case 0:
          scaleAnimation = TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween(begin: 0.2, end: 0.8)
                  .chain(CurveTween(curve: Curves.easeInOut)),
              weight: 50,
            ),
            TweenSequenceItem(
              tween: Tween(begin: 0.8, end: 0.2)
                  .chain(CurveTween(curve: Curves.easeInOut)),
              weight: 50,
            ),
          ]).animate(controller);
          break;
        case 1:
          scaleAnimation = TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween(begin: 0.4, end: 1.0)
                  .chain(CurveTween(curve: Curves.easeInOut)),
              weight: 30,
            ),
            TweenSequenceItem(
              tween: Tween(begin: 1.0, end: 0.3)
                  .chain(CurveTween(curve: Curves.easeInOut)),
              weight: 40,
            ),
            TweenSequenceItem(
              tween: Tween(begin: 0.3, end: 0.4)
                  .chain(CurveTween(curve: Curves.easeInOut)),
              weight: 30,
            ),
          ]).animate(controller);
          break;
        case 2:
          scaleAnimation = TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween(begin: 0.3, end: 0.9)
                  .chain(CurveTween(curve: Curves.easeInOut)),
              weight: 60,
            ),
            TweenSequenceItem(
              tween: Tween(begin: 0.9, end: 0.3)
                  .chain(CurveTween(curve: Curves.easeInOut)),
              weight: 40,
            ),
          ]).animate(controller);
          break;
        case 3:
          scaleAnimation = TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween(begin: 0.5, end: 1.1)
                  .chain(CurveTween(curve: Curves.easeInOut)),
              weight: 40,
            ),
            TweenSequenceItem(
              tween: Tween(begin: 1.1, end: 0.4)
                  .chain(CurveTween(curve: Curves.easeInOut)),
              weight: 40,
            ),
            TweenSequenceItem(
              tween: Tween(begin: 0.4, end: 0.5)
                  .chain(CurveTween(curve: Curves.easeInOut)),
              weight: 20,
            ),
          ]).animate(controller);
          break;
        case 4:
          scaleAnimation = TweenSequence<double>([
            TweenSequenceItem(
              tween: Tween(begin: 0.25, end: 0.7)
                  .chain(CurveTween(curve: Curves.easeInOut)),
              weight: 20,
            ),
            TweenSequenceItem(
              tween: Tween(begin: 0.7, end: 0.6)
                  .chain(CurveTween(curve: Curves.easeInOut)),
              weight: 30,
            ),
            TweenSequenceItem(
              tween: Tween(begin: 0.6, end: 0.25)
                  .chain(CurveTween(curve: Curves.easeInOut)),
              weight: 50,
            ),
          ]).animate(controller);
          break;
        default:
          scaleAnimation = Tween(begin: 0.3, end: 0.5).animate(controller);
      }
    }

    return AnimatedBuilder(
      animation: scaleAnimation,
      builder: (context, child) {
        final maxHeight = 32.0;
        final minHeight = 8.0;
        final height = minHeight + (scaleAnimation.value * (maxHeight - minHeight));
        
        return Container(
          width: 8,
          height: height.clamp(minHeight, maxHeight),
          margin: EdgeInsets.only(right: index < 4 ? 6 : 0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}

