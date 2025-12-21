import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_animations.dart';

/// Vinyl Disc Widget - Exact replica of React Native implementation
/// Displays an animated rotating vinyl record with concentric grooves
class VinylDisc extends StatefulWidget {
  final double size;
  final String? artist;
  final bool isPlaying;

  const VinylDisc({
    super.key,
    required this.size,
    this.artist,
    this.isPlaying = false,
  });

  @override
  State<VinylDisc> createState() => _VinylDiscState();
}

class _VinylDiscState extends State<VinylDisc>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: AppAnimations.discRotationDuration,
    );

    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(VinylDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final centerHoleSize = widget.size * 0.08;
    final labelSize = widget.size * 0.3;

    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationController.value * 2 * math.pi,
          child: child,
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              offset: const Offset(0, 4),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
        ),
        child: CustomPaint(
          painter: _VinylDiscPainter(
            size: widget.size,
            centerHoleSize: centerHoleSize,
            labelSize: labelSize,
            artist: widget.artist,
          ),
        ),
      ),
    );
  }
}

/// Custom painter for vinyl disc with concentric grooves
class _VinylDiscPainter extends CustomPainter {
  final double size;
  final double centerHoleSize;
  final double labelSize;
  final String? artist;

  _VinylDiscPainter({
    required this.size,
    required this.centerHoleSize,
    required this.labelSize,
    this.artist,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(size / 2, size / 2);
    final radius = size / 2;

    // Draw outer vinyl disc (black with border)
    final discPaint = Paint()
      ..color = AppColors.vinylBlack
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius, discPaint);

    // Draw border
    final borderPaint = Paint()
      ..color = AppColors.vinylGray
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawCircle(center, radius, borderPaint);

    // Draw 8 concentric grooves
    final groovePaint = Paint()
      ..color = AppColors.vinylGray
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 8; i++) {
      final grooveRadius = radius - (i * AppSpacing.vinylGrooveSpacing);
      if (grooveRadius > labelSize / 2) {
        canvas.drawCircle(center, grooveRadius, groovePaint);
      }
    }

    // Draw center label (white circle)
    final labelPaint = Paint()
      ..color = AppColors.vinylCenterLabel
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, labelSize / 2, labelPaint);

    // Draw label border
    final labelBorderPaint = Paint()
      ..color = AppColors.vinylCenterBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, labelSize / 2, labelBorderPaint);

    // Draw label text (artist initial)
    final artistInitial = artist != null && artist!.isNotEmpty
        ? artist!.substring(0, 1).toUpperCase()
        : 'M';
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: artistInitial,
        style: TextStyle(
          color: const Color(0xFF333333),
          fontSize: labelSize * 0.15,
          fontWeight: FontWeight.bold,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );

    // Draw center hole (black circle)
    final holePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, centerHoleSize / 2, holePaint);

    // Draw center hole border
    final holeBorderPaint = Paint()
      ..color = AppColors.vinylGray
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawCircle(center, centerHoleSize / 2, holeBorderPaint);
  }

  @override
  bool shouldRepaint(_VinylDiscPainter oldDelegate) {
    return oldDelegate.artist != artist;
  }
}

