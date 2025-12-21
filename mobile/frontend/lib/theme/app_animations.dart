import 'package:flutter/material.dart';

/// Animation system matching the React Native mobile app exactly
/// Durations, curves, and timing functions
class AppAnimations {
  AppAnimations._();

  // Animation durations (in milliseconds)
  static const Duration voiceWaveDuration = Duration(milliseconds: 800);
  static const Duration soundbarLoopDuration = Duration(milliseconds: 600);
  static const Duration discRotationDuration = Duration(seconds: 10);
  static const Duration controlsAutoHideDuration = Duration(milliseconds: 3000);
  static const Duration buttonPressDuration = Duration(milliseconds: 150);
  static const Duration pageTransitionDuration = Duration(milliseconds: 300);
  static const Duration shimmerSweepDuration = Duration(milliseconds: 2000);
  static const Duration fadeInDuration = Duration(milliseconds: 300);
  static const Duration subtleAnimationDuration = Duration(milliseconds: 2000);

  // Animation curves
  static const Curve defaultCurve = Curves.easeOut;
  static const Curve voiceBubbleCurve = Curves.easeInOut;
  static const Curve soundbarCurve = Curves.easeInOut;
  static const Curve buttonPressCurve = Curves.easeInOut;
  static const Curve pageTransitionCurve = Curves.easeInOutCubic;

  // Voice bubble soundbar animation patterns
  static const List<double> soundbar1InputRange = [0.0, 0.5, 1.0];
  static const List<double> soundbar1OutputRange = [0.2, 0.8, 0.2];

  static const List<double> soundbar2InputRange = [0.0, 0.3, 0.7, 1.0];
  static const List<double> soundbar2OutputRange = [0.4, 1.0, 0.3, 0.4];

  static const List<double> soundbar3InputRange = [0.0, 0.6, 1.0];
  static const List<double> soundbar3OutputRange = [0.3, 0.9, 0.3];

  static const List<double> soundbar4InputRange = [0.0, 0.4, 0.8, 1.0];
  static const List<double> soundbar4OutputRange = [0.5, 1.1, 0.4, 0.5];

  static const List<double> soundbar5InputRange = [0.0, 0.2, 0.5, 1.0];
  static const List<double> soundbar5OutputRange = [0.25, 0.7, 0.6, 0.25];

  // Voice bubble wave animation
  static const double waveScaleStart = 1.0;
  static const double waveScaleEnd = 1.2;
  static const double waveOpacityStart = 0.3;
  static const double waveOpacityEnd = 0.8;
  static const double subtleAnimationValue = 0.3;

  // Button press animation
  static const double buttonScaleStart = 1.0;
  static const double buttonScaleEnd = 0.95;

  // Card hover animation
  static const double cardLiftTranslate = -4.0;

  // Shimmer animation
  static const double shimmerStartX = -1.5;
  static const double shimmerEndX = 1.5;

  // Page transition distances
  static const double slideTransitionDistance = 400.0;
  static const double fadeUpStartY = 20.0;

  // Keyframe animation names (for reference)
  static const String fadeInUp = 'fadeInUp';
  static const String slideInRight = 'slideInRight';
  static const String scaleIn = 'scaleIn';
  static const String shimmer = 'shimmer';
  static const String float = 'float';
  static const String glow = 'glow';
  static const String pulse = 'pulse';
  static const String bounce = 'bounce';
}

