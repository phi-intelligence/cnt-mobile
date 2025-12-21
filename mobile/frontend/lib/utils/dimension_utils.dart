import 'package:flutter/material.dart';

/// Screen dimension utilities for responsive design
class DimensionUtils {
  DimensionUtils._();

  /// Get screen size category
  static String getScreenSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 640) return 'mobile';
    if (width < 1024) return 'tablet';
    return 'desktop';
  }

  /// Get responsive padding
  static EdgeInsets getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 640) {
      return const EdgeInsets.all(16);
    } else if (width < 1024) {
      return const EdgeInsets.all(24);
    } else {
      return const EdgeInsets.all(40);
    }
  }

  /// Get responsive horizontal padding
  static double getHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 640) {
      return 16;
    } else if (width < 1024) {
      return 24;
    } else {
      return 40;
    }
  }

  /// Get number of columns for grid based on screen size
  static int getGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 480) return 1;
    if (width < 768) return 2;
    if (width < 1024) return 3;
    return 4;
  }

  /// Check if small screen (for bottom tab bar adjustments)
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 400;
  }

  /// Get voice bubble size based on screen
  static double getVoiceBubbleSize(BuildContext context) {
    return 100.0; // Fixed size matching React Native
  }

  /// Get vinyl disc size based on screen
  static double getVinylDiscSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    return (width * 0.7).clamp(0.0, height * 0.4);
  }
}

