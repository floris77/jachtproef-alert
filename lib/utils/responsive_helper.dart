import 'package:flutter/material.dart';

class ResponsiveHelper {
  static const double _smallScreenWidth = 375.0; // iPhone SE, iPhone 12 mini
  static const double _largeScreenWidth = 414.0; // iPhone Plus, Pro Max
  static const double _tabletWidth = 600.0; // Tablet breakpoint
  static const double _largeTabletWidth = 900.0; // Large tablet breakpoint
  static const double _shortScreenHeight = 700.0; // Shorter devices
  static const double _verySmallScreenWidth = 320.0; // Very small devices

  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < _smallScreenWidth;
  }

  static bool isVerySmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < _verySmallScreenWidth;
  }

  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > _largeScreenWidth && !isTablet(context);
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= _tabletWidth;
  }

  static bool isLargeTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= _largeTabletWidth;
  }

  static bool isShortScreen(BuildContext context) {
    return MediaQuery.of(context).size.height < _shortScreenHeight;
  }

  // Responsive padding
  static double getHorizontalPadding(BuildContext context) {
    if (isLargeTablet(context)) return 48.0;
    if (isTablet(context)) return 40.0;
    if (isVerySmallScreen(context)) return 12.0;
    if (isSmallScreen(context)) return 16.0;
    if (isLargeScreen(context)) return 32.0;
    return 24.0;
  }

  static double getVerticalPadding(BuildContext context) {
    if (isTablet(context)) return 32.0;
    if (isShortScreen(context)) return 12.0;
    if (isSmallScreen(context)) return 16.0;
    return 24.0;
  }

  // Responsive font sizes
  static double getTitleFontSize(BuildContext context) {
    if (isLargeTablet(context)) return 42.0;
    if (isTablet(context)) return 38.0;
    if (isVerySmallScreen(context)) return 24.0;
    if (isSmallScreen(context)) return 28.0;
    if (isLargeScreen(context)) return 36.0;
    return 32.0;
  }

  static double getSubtitleFontSize(BuildContext context) {
    if (isLargeTablet(context)) return 22.0;
    if (isTablet(context)) return 20.0;
    if (isVerySmallScreen(context)) return 12.0;
    if (isSmallScreen(context)) return 14.0;
    if (isLargeScreen(context)) return 18.0;
    return 16.0;
  }

  static double getBodyFontSize(BuildContext context) {
    if (isLargeTablet(context)) return 19.0;
    if (isTablet(context)) return 18.0;
    if (isVerySmallScreen(context)) return 13.0;
    if (isSmallScreen(context)) return 14.0;
    if (isLargeScreen(context)) return 17.0;
    return 16.0;
  }

  static double getCaptionFontSize(BuildContext context) {
    if (isLargeTablet(context)) return 16.0;
    if (isTablet(context)) return 15.0;
    if (isVerySmallScreen(context)) return 11.0;
    if (isSmallScreen(context)) return 12.0;
    if (isLargeScreen(context)) return 14.0;
    return 13.0;
  }

  // Responsive spacing
  static double getSpacing(BuildContext context, double baseSpacing) {
    if (isLargeTablet(context)) return baseSpacing * 1.4;
    if (isTablet(context)) return baseSpacing * 1.2;
    if (isVerySmallScreen(context)) return baseSpacing * 0.6;
    if (isSmallScreen(context)) return baseSpacing * 0.75;
    if (isShortScreen(context)) return baseSpacing * 0.8;
    return baseSpacing;
  }

  // Responsive icon sizes
  static double getIconSize(BuildContext context, double baseSize) {
    if (isLargeTablet(context)) return baseSize * 1.4;
    if (isTablet(context)) return baseSize * 1.3;
    if (isVerySmallScreen(context)) return baseSize * 0.8;
    if (isSmallScreen(context)) return baseSize * 0.9;
    if (isLargeScreen(context)) return baseSize * 1.2;
    return baseSize;
  }

  // Responsive button heights
  static double getButtonHeight(BuildContext context) {
    if (isLargeTablet(context)) return 64.0;
    if (isTablet(context)) return 60.0;
    if (isVerySmallScreen(context)) return 48.0;
    if (isSmallScreen(context)) return 52.0;
    return 56.0;
  }

  // Responsive card padding
  static EdgeInsets getCardPadding(BuildContext context) {
    final horizontal = getHorizontalPadding(context);
    final vertical = getVerticalPadding(context);
    return EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical * 0.75);
  }

  // Responsive card margin
  static EdgeInsets getCardMargin(BuildContext context) {
    if (isVerySmallScreen(context)) return const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0);
    if (isSmallScreen(context)) return const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0);
    return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0);
  }

  // Responsive button padding
  static EdgeInsets getButtonPadding(BuildContext context) {
    if (isVerySmallScreen(context)) return const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0);
    if (isSmallScreen(context)) return const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0);
    return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0);
  }

  // Responsive list item height
  static double getListItemHeight(BuildContext context) {
    if (isVerySmallScreen(context)) return 60.0;
    if (isSmallScreen(context)) return 70.0;
    return 80.0;
  }

  // Check if device needs compact layout
  static bool needsCompactLayout(BuildContext context) {
    return isSmallScreen(context) || isShortScreen(context);
  }

  // Get responsive text style
  static TextStyle getResponsiveTextStyle(BuildContext context, TextStyle baseStyle) {
    double scaleFactor = 1.0;
    
    if (isVerySmallScreen(context)) {
      scaleFactor = 0.85;
    } else if (isSmallScreen(context)) {
      scaleFactor = 0.9;
    } else if (isLargeScreen(context)) {
      scaleFactor = 1.1;
    }

    return baseStyle.copyWith(
      fontSize: (baseStyle.fontSize ?? 16.0) * scaleFactor,
    );
  }

  // Get responsive SizedBox height
  static Widget getResponsiveSpacing(BuildContext context, double height) {
    return SizedBox(height: getSpacing(context, height));
  }

  // Get responsive container constraints
  static BoxConstraints getResponsiveConstraints(BuildContext context, {
    double? maxWidth,
    double? maxHeight,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return BoxConstraints(
      maxWidth: maxWidth ?? screenWidth * 0.9,
      maxHeight: maxHeight ?? screenHeight * 0.8,
    );
  }
} 