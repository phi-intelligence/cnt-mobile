import 'package:flutter/material.dart';

/// Responsive grid delegate utility for web screens
/// Provides adaptive grid layouts based on screen width
class ResponsiveGridDelegate {
  ResponsiveGridDelegate._();

  /// Get responsive grid delegate based on screen width
  /// 
  /// Parameters:
  /// - desktop: Number of columns for desktop (> 1024px)
  /// - tablet: Number of columns for tablet (640px - 1024px)
  /// - mobile: Number of columns for mobile (< 640px)
  /// - childAspectRatio: Aspect ratio of grid items (default 0.75)
  /// - crossAxisSpacing: Horizontal spacing between items
  /// - mainAxisSpacing: Vertical spacing between items
  static SliverGridDelegateWithFixedCrossAxisCount getResponsiveGridDelegate(
    BuildContext context, {
    required int desktop,
    required int tablet,
    required int mobile,
    double childAspectRatio = 0.75,
    double crossAxisSpacing = 16.0,
    double mainAxisSpacing = 16.0,
  }) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount;

    if (width < 640) {
      crossAxisCount = mobile;
    } else if (width < 1024) {
      crossAxisCount = tablet;
    } else {
      crossAxisCount = desktop;
    }

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      childAspectRatio: childAspectRatio,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
    );
  }

  /// Get responsive grid columns count
  static int getGridColumns(
    BuildContext context, {
    required int desktop,
    required int tablet,
    required int mobile,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width < 640) {
      return mobile;
    } else if (width < 1024) {
      return tablet;
    } else {
      return desktop;
    }
  }

  /// Get responsive padding based on screen size
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
  static double getResponsiveHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 640) {
      return 16;
    } else if (width < 1024) {
      return 24;
    } else {
      return 40;
    }
  }

  /// Get responsive max content width for centering content on large screens
  /// This prevents content from being too wide on large desktop screens
  static double getMaxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 640) {
      return double.infinity; // Full width on mobile
    } else if (width < 1024) {
      return 800; // Tablet max width
    } else {
      return 1200; // Desktop max width (prevents content from being too wide)
    }
  }

  /// Get responsive max width for post cards / content cards
  /// Used for community posts, cards, etc.
  static double getMaxCardWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 640) {
      return double.infinity; // Full width on mobile
    } else if (width < 1024) {
      return 400; // Tablet max width - reduced
    } else {
      return 450; // Desktop max width - reduced considerably
    }
  }
}

