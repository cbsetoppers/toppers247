import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/theme_provider.dart';
import '../../core/theme/app_theme.dart';
import 'home_screen.dart';
import '../../features/chat/chat_screen.dart';
import 'store_screen.dart';
import 'syllabus_tracker_screen.dart';
import '../../features/focus/focus_companion_screen.dart';
import '../widgets/custom_bottom_nav_bar.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  late final List<Widget> _screens = [
    const HomeScreen(),
    const FocusCompanionScreen(), // Study tab — Focus Companion (LOLI)
    ChatScreen(onBack: () => _onItemTapped(0)),
    const SyllabusTrackerScreen(),
    const StoreScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<bool> _onWillPop() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'EXIT APP?',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 1,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'ARE YOU SURE YOU WANT TO LEAVE T0PPERS 24/7?',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.black54,
            letterSpacing: 0.5,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'NO, STAY',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    'YES, EXIT',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final primaryColor = AppTheme.primaryColor;
    final isChatPage = _selectedIndex == 2;

    final scaffold = Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: Container(
          key: ValueKey<int>(_selectedIndex),
          child: _screens[_selectedIndex],
        ),
      ),
      bottomNavigationBar: isChatPage
          ? const SizedBox.shrink()
          : CustomBottomNavBar(
              selectedIndex: _selectedIndex,
              onTap: _onItemTapped,
              primaryColor: primaryColor,
            ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          exit(0);
        }
      },
      child: scaffold,
    );
  }
}

class StudyPlaceholderScreen extends StatelessWidget {
  const StudyPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('STUDY ZONE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.handyman_rounded,
                size: 64,
                color: Theme.of(context).primaryColor,
              ).animate(onPlay: (controller) => controller.repeat(reverse: true))
               .shake(duration: const Duration(seconds: 1), curve: Curves.easeInOut)
               .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1)),
            ),
            const SizedBox(height: 32),
            Text(
              'CRAFTING YOUR STUDY VAULT',
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.5),
            const SizedBox(height: 8),
            Text(
              'WILL BE AVAILABLE SOON',
              style: GoogleFonts.outfit(
                color: Theme.of(context).primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 800.ms),
          ],
        ),
      ),
    );
  }
}
