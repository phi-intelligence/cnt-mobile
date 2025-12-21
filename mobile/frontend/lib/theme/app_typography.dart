import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography system matching the React Native mobile app exactly
/// Based on Inter font family and website typography
class AppTypography {
  AppTypography._();

  // Font families
  static const String fontSans = 'Inter';
  static const String fontSerif = 'Georgia';
  static const String fontMono = 'Menlo';

  // Font sizes (matching React Native)
  static const double fontSizeXS = 12;
  static const double fontSizeSM = 14;
  static const double fontSizeBase = 16;
  static const double fontSizeLG = 18;
  static const double fontSizeXL = 20;
  static const double fontSize2XL = 24;
  static const double fontSize3XL = 30;
  static const double fontSize4XL = 36;
  static const double fontSize5XL = 48;
  static const double fontSize6XL = 60;
  static const double fontSize7XL = 72;

  // Font weights (matching React Native)
  static const FontWeight fontWeightNormal = FontWeight.w400;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightSemibold = FontWeight.w600;
  static const FontWeight fontWeightBold = FontWeight.w700;

  // Line heights (matching React Native)
  static const double lineHeightTight = 1.25;
  static const double lineHeightSnug = 1.375;
  static const double lineHeightNormal = 1.5;
  static const double lineHeightRelaxed = 1.625;
  static const double lineHeightLoose = 2.0;

  // Text styles for common use cases
  static TextStyle get heroTitle => GoogleFonts.inter(
        fontSize: fontSize4XL,
        fontWeight: fontWeightBold,
        height: lineHeightTight,
      );

  static TextStyle get heading1 => GoogleFonts.inter(
        fontSize: fontSize3XL,
        fontWeight: fontWeightBold,
        height: lineHeightTight,
      );

  static TextStyle get heading2 => GoogleFonts.inter(
        fontSize: fontSize2XL,
        fontWeight: fontWeightBold,
        height: lineHeightTight,
      );

  static TextStyle get heading3 => GoogleFonts.inter(
        fontSize: fontSizeXL,
        fontWeight: fontWeightSemibold,
        height: lineHeightSnug,
      );

  static TextStyle get heading4 => GoogleFonts.inter(
        fontSize: fontSizeLG,
        fontWeight: fontWeightSemibold,
        height: lineHeightNormal,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: fontSizeBase,
        fontWeight: fontWeightNormal,
        height: lineHeightNormal,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: fontSizeBase,
        fontWeight: fontWeightMedium,
        height: lineHeightNormal,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: fontSizeSM,
        fontWeight: fontWeightNormal,
        height: lineHeightNormal,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: fontSizeXS,
        fontWeight: fontWeightNormal,
        height: lineHeightNormal,
      );

  static TextStyle get button => GoogleFonts.inter(
        fontSize: fontSizeBase,
        fontWeight: fontWeightSemibold,
        height: lineHeightNormal,
        letterSpacing: 0.5,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontSize: fontSizeSM,
        fontWeight: fontWeightMedium,
        height: lineHeightNormal,
      );
}

