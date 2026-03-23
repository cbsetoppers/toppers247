import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_settings_model.dart';

/// Shown when the `settings` table has `maintenance = true`.
/// Operators (admins) bypass this screen and see the app normally.
class MaintenanceScreen extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onRetry;

  const MaintenanceScreen({
    super.key,
    required this.settings,
    required this.onRetry,
  });

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen>
    with SingleTickerProviderStateMixin {
  bool _isRetrying = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    setState(() => _isRetrying = true);
    await Future.delayed(const Duration(milliseconds: 800));
    widget.onRetry();
    if (mounted) setState(() => _isRetrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _showExitDialog(context, isDark);
        if (shouldExit == true) {
          exit(0);
        }
      },
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0B0B0F)
            : const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Stack(
            children: [
              // Background decoration circles
              Positioned(
                top: -80,
                right: -80,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryColor.withOpacity(0.04),
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -60,
                child: Container(
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange.withOpacity(0.04),
                  ),
                ),
              ),

              // Main content
              Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated gear icon
                      _buildAnimatedIcon(isDark),
                      const SizedBox(height: 40),

                      // Title
                      Text(
                        widget.settings.maintenanceTitle.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                          letterSpacing: 1.5,
                          height: 1.2,
                        ),
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),

                      const SizedBox(height: 20),

                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (_, _) => Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.orange.withOpacity(
                                    0.4 + 0.6 * _pulseController.value,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'MAINTENANCE IN PROGRESS',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.orange,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 600.ms),

                      const SizedBox(height: 32),

                      // Message card
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.04)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.grey.shade100,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isDark ? 0.3 : 0.06,
                              ),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              widget.settings.maintenanceMessage,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.black.withOpacity(0.65),
                                height: 1.7,
                              ),
                            ),
                            if (widget.settings.contactEmail != null) ...[
                              const SizedBox(height: 20),
                              Divider(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.grey.shade100,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.mail_outline_rounded,
                                    size: 16,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.settings.contactEmail!,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.15),

                      const SizedBox(height: 40),

                      // What we're working on chips
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children:
                            [
                                  _buildChip('🚀 Performance upgrades', isDark),
                                  _buildChip('🛡️ Security patches', isDark),
                                  _buildChip('✨ New features', isDark),
                                  _buildChip('🔧 Bug fixes', isDark),
                                ]
                                .asMap()
                                .entries
                                .map(
                                  (e) => e.value
                                      .animate()
                                      .fadeIn(delay: (800 + e.key * 80).ms)
                                      .scale(begin: const Offset(0.8, 0.8)),
                                )
                                .toList(),
                      ),

                      const SizedBox(height: 48),

                      // Retry button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isRetrying ? null : _retry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: _isRetrying
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'CHECKING...',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.refresh_rounded, size: 20),
                                    const SizedBox(width: 10),
                                    Text(
                                      'CHECK AGAIN',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ).animate().fadeIn(delay: 1200.ms).slideY(begin: 0.3),

                      const SizedBox(height: 24),

                      // App branding at bottom
                      Text(
                        'T0PPERS 24/7',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryColor.withOpacity(0.5),
                          letterSpacing: 3,
                        ),
                      ).animate().fadeIn(delay: 1400.ms),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showExitDialog(BuildContext context, bool isDark) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardBlack : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppTheme.primaryGold.withOpacity(0.2)),
        ),
        title: Text(
          'EXIT APPLICATION?',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: isDark ? Colors.white : AppTheme.textHeadingColor,
            letterSpacing: 1,
          ),
        ),
        content: Text(
          'ARE YOU SURE YOU WANT TO QUIT T0PPERS 24/7?',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white60 : Colors.black54,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'KEEP STUDYING',
              style: GoogleFonts.outfit(
                color: Colors.grey,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.1),
              foregroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.redAccent, width: 1),
              ),
            ),
            child: Text(
              'EXIT NOW',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedIcon(bool isDark) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, _) => Container(
            width: 130 + 20 * _pulseController.value,
            height: 130 + 20 * _pulseController.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.orange.withOpacity(
                0.06 * (1 - _pulseController.value * 0.3),
              ),
            ),
          ),
        ),
        // Inner card
        Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.orange.withOpacity(0.08),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.25),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.construction_rounded,
                size: 50,
                color: Colors.orange,
              ),
            )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .rotate(begin: -0.05, end: 0.05, duration: 2.seconds),
      ],
    ).animate().scale(
      curve: Curves.elasticOut,
      duration: 900.ms,
      delay: 100.ms,
    );
  }

  Widget _buildChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }
}
