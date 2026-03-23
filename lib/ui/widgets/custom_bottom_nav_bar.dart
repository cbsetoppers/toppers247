import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;
  final Color primaryColor;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.cardBlack : Colors.white;
    
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 65,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: const Size(double.infinity, 65),
                painter: _NavBarPainter(
                  bgColor: bgColor,
                  primaryColor: primaryColor,
                ),
              ),
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: selectedIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
                      label: 'Home',
                      isSelected: selectedIndex == 0,
                      primaryColor: primaryColor,
                      onTap: () => onTap(0),
                    ),
                    _NavItem(
                      icon: selectedIndex == 1 ? Icons.auto_stories_rounded : Icons.auto_stories_outlined,
                      label: 'Study',
                      isSelected: selectedIndex == 1,
                      primaryColor: primaryColor,
                      onTap: () => onTap(1),
                    ),
                    const SizedBox(width: 56),
                    _NavItem(
                      icon: selectedIndex == 3 ? Icons.track_changes_rounded : Icons.track_changes_outlined,
                      label: 'Tracker',
                      isSelected: selectedIndex == 3,
                      primaryColor: primaryColor,
                      onTap: () => onTap(3),
                    ),
                    _NavItem(
                      icon: selectedIndex == 4 ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined,
                      label: 'Store',
                      isSelected: selectedIndex == 4,
                      primaryColor: primaryColor,
                      onTap: () => onTap(4),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: _AIFloatingButton(
                    isSelected: selectedIndex == 2,
                    primaryColor: primaryColor,
                    onTap: () => onTap(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isSelected 
        ? primaryColor 
        : (isDark ? Colors.white54 : Colors.grey.shade600);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AIFloatingButton extends StatelessWidget {
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _AIFloatingButton({
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: primaryColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          isSelected ? Icons.psychology_rounded : Icons.psychology_outlined,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}

class _NavBarPainter extends CustomPainter {
  final Color bgColor;
  final Color primaryColor;

  _NavBarPainter({
    required this.bgColor,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2 - 40, 0);
    
    path.quadraticBezierTo(
      size.width / 2 - 28, 0,
      size.width / 2 - 28, 8,
    );
    
    path.arcToPoint(
      Offset(size.width / 2 + 28, 8),
      radius: const Radius.circular(28),
      clockwise: false,
    );
    
    path.quadraticBezierTo(
      size.width / 2 + 28, 0,
      size.width / 2 + 40, 0,
    );
    
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
