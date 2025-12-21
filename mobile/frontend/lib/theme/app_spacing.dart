import 'package:flutter/material.dart';

/// Spacing system matching the React Native mobile app exactly
/// 8px grid system for consistent spacing
class AppSpacing {
  AppSpacing._();

  // Spacing values (all in logical pixels, matching 8px grid)
  static const double tiny = 4.0;
  static const double extraSmall = 8.0;
  static const double small = 12.0;
  static const double medium = 16.0;
  static const double large = 24.0;
  static const double extraLarge = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;

  // Common spacing shortcuts
  static const EdgeInsets allTiny = EdgeInsets.all(tiny);
  static const EdgeInsets allExtraSmall = EdgeInsets.all(extraSmall);
  static const EdgeInsets allSmall = EdgeInsets.all(small);
  static const EdgeInsets allMedium = EdgeInsets.all(medium);
  static const EdgeInsets allLarge = EdgeInsets.all(large);
  static const EdgeInsets allExtraLarge = EdgeInsets.all(extraLarge);

  static const EdgeInsets horizontalSmall = EdgeInsets.symmetric(horizontal: small);
  static const EdgeInsets horizontalMedium = EdgeInsets.symmetric(horizontal: medium);
  static const EdgeInsets horizontalLarge = EdgeInsets.symmetric(horizontal: large);
  static const EdgeInsets horizontalExtraLarge = EdgeInsets.symmetric(horizontal: extraLarge);

  static const EdgeInsets verticalSmall = EdgeInsets.symmetric(vertical: small);
  static const EdgeInsets verticalMedium = EdgeInsets.symmetric(vertical: medium);
  static const EdgeInsets verticalLarge = EdgeInsets.symmetric(vertical: large);
  static const EdgeInsets verticalExtraLarge = EdgeInsets.symmetric(vertical: extraLarge);

  // Border radius (matching React Native)
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusFull = 9999.0; // Circular

  // Icon sizes
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeXLarge = 48.0;
  static const double iconSizeXXLarge = 64.0;

  // Touch target sizes (minimum for accessibility)
  static const double minTouchTarget = 44.0;

  // Voice bubble specific
  static const double voiceBubbleSize = 100.0;
  static const double voiceBubbleBorderRadius = 50.0; // Circular
  static const double voiceBubbleIconSize = 32.0;
  static const double soundbarWidth = 4.0;
  static const double soundbarGap = 3.0;
  static const double soundbarBorderRadius = 2.0;

  // Vinyl disc dimensions (relative calculations will be in widget)
  static const double vinylDiscMinSize = 200.0;
  static const double vinylCenterLabelRatio = 0.3; // 30% of disc size
  static const double vinylCenterHoleRatio = 0.08; // 8% of disc size
  static const double vinylGrooveSpacing = 15.0;
  static const double vinylGrooveBorderWidth = 1.0;
  static const double vinylOuterBorderWidth = 3.0;

  // Bottom tab bar (matching React Native)
  static const double bottomTabBarHeightIOS = 85.0;
  static const double bottomTabBarHeightAndroid = 60.0;
  static const double bottomTabBarPaddingTopIOS = 8.0;
  static const double bottomTabBarPaddingTopAndroid = 8.0;
  static const double bottomTabBarPaddingBottomIOS = 20.0;
  static const double bottomTabBarPaddingBottomAndroid = 8.0;
}

