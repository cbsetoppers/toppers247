import 'package:flutter/material.dart';

class ResponsiveHelper {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
  
  static const double maxContentWidth = 1200;
  static const double maxFormWidth = 500;
  static const double maxCardWidth = 400;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static int getGridCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1100) return 4;
    if (width > 800) return 3;
    return 2;
  }

  static double getDialogWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > desktopBreakpoint) return width * 0.5;
    if (width > tabletBreakpoint) return width * 0.6;
    if (width > mobileBreakpoint) return width * 0.8;
    return width * 0.9;
  }

  static double getResponsiveSize(double baseSize, BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > desktopBreakpoint) return baseSize * 1.2;
    if (width > tabletBreakpoint) return baseSize * 1.1;
    return baseSize;
  }

  static EdgeInsets getScreenPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > desktopBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 48, vertical: 24);
    } else if (width > tabletBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
    } else if (width > mobileBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  }

  static double getContentPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > desktopBreakpoint) return 48.0;
    if (width > tabletBreakpoint) return 32.0;
    if (width > mobileBreakpoint) return 24.0;
    return 16.0;
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, bool isDesktop, bool isTablet, bool isMobile) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < ResponsiveHelper.mobileBreakpoint;
        final isTablet = constraints.maxWidth >= ResponsiveHelper.mobileBreakpoint &&
            constraints.maxWidth < ResponsiveHelper.tabletBreakpoint;
        final isDesktop = constraints.maxWidth >= ResponsiveHelper.tabletBreakpoint;
        return builder(context, isDesktop, isTablet, isMobile);
      },
    );
  }
}

class CenteredContent extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const CenteredContent({
    super.key,
    required this.child,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? ResponsiveHelper.maxContentWidth,
        ),
        child: child,
      ),
    );
  }
}
