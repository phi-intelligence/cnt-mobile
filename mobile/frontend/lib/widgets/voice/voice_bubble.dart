import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Voice Bubble Component
/// Displays a static soundbar glyph within a circular bubble
class VoiceBubble extends StatelessWidget {
  static const String defaultHeroTag = 'voice-bubble';
  final VoidCallback? onPressed;
  final bool isActive;
  final String label;
  final String? heroTag;
  final bool enableHero;
  final Color? labelColor;
  final double? size;

  const VoiceBubble({
    super.key,
    this.onPressed,
    this.isActive = false,
    this.label = '',
    this.heroTag,
    this.enableHero = true,
    this.labelColor,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedLabelColor = labelColor ?? AppColors.textInverse;
    final bubbleSize = size ?? AppSpacing.voiceBubbleSize;

    Widget bubble = GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (isActive)
                Container(
                  width: bubbleSize + 12,
                  height: bubbleSize + 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryMain.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                ),
              Container(
                width: bubbleSize,
                height: bubbleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.warmBrown,
                  border: Border.all(
                    color: AppColors.borderPrimary.withOpacity(0.4),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      offset: const Offset(0, 2),
                      blurRadius: 6,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: _StaticSoundbarGlyph(size: bubbleSize),
              ),
            ],
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.small),
            Text(
              isActive ? 'Tap to stop' : label,
              style: TextStyle(
                color: resolvedLabelColor,
                fontSize: size != null ? (size! / 8).clamp(12.0, 16.0) : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );

    if (enableHero) {
      bubble = Hero(
        tag: heroTag ?? VoiceBubble.defaultHeroTag,
        child: Material(
          color: Colors.transparent,
          child: bubble,
        ),
      );
    }

    return bubble;
  }
}

class _StaticSoundbarGlyph extends StatelessWidget {
  final double size;
  
  const _StaticSoundbarGlyph({required this.size});

  @override
  Widget build(BuildContext context) {
    // Scale bars proportionally based on size
    final scale = size / AppSpacing.voiceBubbleSize;
    final bars = [12.0 * scale, 18.0 * scale, 24.0 * scale, 18.0 * scale, 12.0 * scale];
    final barWidth = 4 * scale;
    final barSpacing = 3 * scale;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(bars.length, (index) {
        return Container(
          width: barWidth,
          height: bars[index],
          margin: EdgeInsets.only(right: index == bars.length - 1 ? 0 : barSpacing),
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: BorderRadius.circular(2 * scale),
          ),
        );
      }),
    );
  }
}

