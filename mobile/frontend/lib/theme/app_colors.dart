import 'package:flutter/material.dart';

/// Color palette matching the React Native mobile app exactly
/// Based on Christ New Tabernacle website colors
class AppColors {
  AppColors._();

  // Primary colors (matching website)
  static const Color primaryMain = Color(0xFF8B7355); // hsl(30, 25%, 45%) - Warm Brown
  static const Color primaryLight = Color(0xFFA68B6B); // Lighter variant
  static const Color primaryDark = Color(0xFF6B5A3F); // Darker variant
  static const Color warmBrown = Color(0xFF92775B); // Requested hero/banner brown

  // Accent colors
  static const Color accentMain = Color(0xFFD4A574); // hsl(45, 35%, 65%) - Golden Yellow
  static const Color accentLight = Color(0xFFE6C49A); // Lighter variant
  static const Color accentDark = Color(0xFFB8935A); // Darker variant

  // Background colors
  static const Color backgroundPrimary = Color(0xFFF7F5F2); // hsl(35, 20%, 97%) - Cream
  static const Color backgroundSecondary = Color(0xFFFCFAF8); // Card background
  static const Color backgroundTertiary = Color(0xFFF0EDE8); // Alternative background

  // Foreground/Text colors
  static const Color foregroundPrimary = Color(0xFF2D2520); // hsl(25, 15%, 15%) - Dark Brown
  static const Color foregroundSecondary = Color(0xFF5A4F47); // Medium text
  static const Color foregroundTertiary = Color(0xFF8B7D73); // Light text
  static const Color foregroundPlaceholder = Color(0xFFA69B94); // Placeholder text

  // Secondary colors
  static const Color secondaryMain = Color(0xFFD9D1C7); // hsl(35, 15%, 88%) - Medium Cream
  static const Color secondaryLight = Color(0xFFE8E4E0); // Light variant
  static const Color secondaryDark = Color(0xFFC4B8A8); // Dark variant

  // Muted colors
  static const Color mutedMain = Color(0xFFE8E4E0); // hsl(35, 15%, 92%) - Light Cream
  static const Color mutedLight = Color(0xFFF0EDE8); // Light variant
  static const Color mutedDark = Color(0xFFD9D1C7); // Dark variant

  // Border colors
  static const Color borderPrimary = Color(0xFFD4C5B8); // hsl(35, 15%, 85%) - Soft Brown
  static const Color borderSecondary = Color(0xFFE8E4E0); // Light border
  static const Color borderFocus = Color(0xFF8B7355); // Focus border

  // Card colors
  static const Color cardBackground = Color(0xFFFCFAF8); // hsl(35, 25%, 98%) - Card Background
  static const Color cardForeground = Color(0xFF2D2520); // hsl(25, 15%, 15%) - Card Text
  static const Color cardBorder = Color(0xFFE8E4E0); // Card border

  // Status colors
  static const Color successMain = Color(0xFF22C55E); // Green for success
  static const Color successLight = Color(0xFF4ADE80); // Light variant
  static const Color successDark = Color(0xFF16A34A); // Dark variant

  static const Color warningMain = Color(0xFFF59E0B); // Amber for warnings
  static const Color warningLight = Color(0xFFFBBF24); // Light variant
  static const Color warningDark = Color(0xFFD97706); // Dark variant

  static const Color errorMain = Color(0xFFEF4444); // Red for errors
  static const Color errorLight = Color(0xFFF87171); // Light variant
  static const Color errorDark = Color(0xFFDC2626); // Dark variant

  static const Color infoMain = Color(0xFF3B82F6); // Blue for info
  static const Color infoLight = Color(0xFF60A5FA); // Light variant
  static const Color infoDark = Color(0xFF2563EB); // Dark variant

  static const Color destructiveMain = Color(0xFFEF4444); // Destructive actions
  static const Color destructiveForeground = Color(0xFFFCFAF8); // Text on destructive background

  // Text colors
  static const Color textPrimary = Color(0xFF2D2520); // Main text
  static const Color textSecondary = Color(0xFF5A4F47); // Secondary text
  static const Color textTertiary = Color(0xFF8B7D73); // Tertiary text
  static const Color textPlaceholder = Color(0xFFA69B94); // Placeholder text
  static const Color textInverse = Color(0xFFF7F5F2); // Inverse text (on dark backgrounds)

  // Glassmorphic effects (transparent colors)
  static const Color glassLight = Color.fromRGBO(255, 255, 255, 0.15);
  static const Color glassMedium = Color.fromRGBO(255, 255, 255, 0.2);
  static const Color glassDark = Color.fromRGBO(255, 255, 255, 0.05);
  static const Color glassPrimary = Color.fromRGBO(139, 115, 85, 0.2);
  static const Color glassAccent = Color.fromRGBO(212, 165, 116, 0.2);

  // Vinyl disc colors - cream/beige theme
  static const Color vinylBlack = Color(0xFFD4C5B8); // Cream/brown
  static const Color vinylGray = Color(0xFF8B7D73); // Medium brown for grooves
  static const Color vinylCenterLabel = Color(0xFFF7F5F2); // Light cream center
  static const Color vinylCenterBorder = Color(0xFFD4C5B8); // Cream border

  // Live stream colors
  static const Color liveRed = Color(0xFFFF0000);
  static const Color liveIndicator = Color(0xFFFF0000);
}

