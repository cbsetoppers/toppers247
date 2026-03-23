import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../models/app_settings_model.dart';
import '../../core/theme/app_theme.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';
import 'maintenance_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  int _userCount = 0;
  bool _countLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserCount();
    _bootstrap(); // Settings check + auth check combined
  }

  Future<void> _loadUserCount() async {
    try {
      final count = await ref.read(supabaseServiceProvider).fetchUserCount();
      if (mounted) {
        setState(() {
          _userCount = count;
          _countLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading user count: $e');
    }
  }

  /// Primary bootstrap sequence:
  /// 1. Wait for splash animation (minimum display time)
  /// 2. Fetch app settings from Supabase
  /// 3. If maintenance ON and NOT an operator → show MaintenanceScreen
  /// 4. Otherwise proceed with auth check
  Future<void> _bootstrap() async {
    if (!kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 2500));
    }
    if (!mounted) return;

    // ── Step 1: Fetch app settings (maintenance check) ──────────────────────
    final settings = await ref.read(supabaseServiceProvider).fetchAppSettings();

    if (!mounted) return;

    // ── Step 2: Check if operator (operators bypass maintenance mode) ───────
    if (settings.isMaintenanceMode) {
      // Check if the current user is an operator — operators always bypass
      final session = Supabase.instance.client.auth.currentSession;
      bool isOperator = false;
      if (session != null) {
        try {
          final uuid = session.user.id;
          final profile = await ref
              .read(supabaseServiceProvider)
              .fetchProfileById(uuid);
          isOperator = profile?.isOperator == true;
        } catch (_) {}
      }

      if (!isOperator) {
        // Show maintenance screen — operators skip this
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, _, _) => MaintenanceScreen(
                settings: settings,
                onRetry: _restartBootstrap,
              ),
              transitionsBuilder: (_, a, _, c) =>
                  FadeTransition(opacity: a, child: c),
              transitionDuration: 600.ms,
            ),
          );
        }
        return;
      }
      debugPrint('🔑 Operator bypassing maintenance mode');
    }

    // ── Step 3: Normal auth flow ─────────────────────────────────────────────
    await _checkAuth();
  }

  /// Called by MaintenanceScreen's "CHECK AGAIN" button.
  /// Re-pushes SplashScreen so the full bootstrap runs again.
  void _restartBootstrap() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const SplashScreen(),
        transitionsBuilder: (_, a, _, c) =>
            FadeTransition(opacity: a, child: c),
        transitionDuration: 400.ms,
      ),
    );
  }

  Future<void> _checkAuth() async {
    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      await ref.read(authProvider.notifier).restoreSession();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const MainNavigationScreen(),
          transitionsBuilder: (_, a, _, c) =>
              FadeTransition(opacity: a, child: c),
          transitionDuration: 1.seconds,
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const LoginScreen(),
          transitionsBuilder: (_, a, _, c) =>
              FadeTransition(opacity: a, child: c),
          transitionDuration: 1.seconds,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const Scaffold();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          gradient: LinearGradient(
            colors: isDark
                ? [Colors.black, Color(0xFF1A1A1A)]
                : [const Color(0xFFF8FAFC), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.cardBlack : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGold.withOpacity(0.2),
                          blurRadius: 40,
                          offset: Offset(0, 10),
                        ),
                      ],
                      border: Border.all(
                        color: AppTheme.primaryGold.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child:
                        Image.asset('assets/logo.png', width: 100, height: 100)
                            .animate()
                            .scale(duration: 800.ms, curve: Curves.easeOutBack)
                            .shimmer(delay: 1.seconds, duration: 2.seconds),
                  ),
                  SizedBox(height: 32),
                  Text(
                    'T0PPERS 24/7',
                    style: GoogleFonts.outfit(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryGold,
                      letterSpacing: 3,
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),
                  Container(
                    width: 60,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ).animate().fadeIn(delay: 600.ms).scaleX(),
                ],
              ),
            ),
            if (_countLoaded)
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Text(
                      'THE PREMIER CHOICE OF',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primaryGold.withOpacity(0.7),
                        letterSpacing: 3,
                      ),
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: AppTheme.primaryGold.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '$_userCount+ AMBITIOUS STUDENTS',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryGold,
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 1.2.seconds).slideY(begin: 0.5),
              ),
          ],
        ),
      ),
    );
  }
}
