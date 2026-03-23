import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers/theme_provider.dart';
import 'camera_focus_detector.dart';
import 'focus_fullscreen_page.dart';
import 'focus_models.dart';
import 'focus_timer_controller.dart';
import 'robot_eyes_widget.dart';
import 'study_mini_tools.dart';
import '../../providers/settings_provider.dart';
import '../../providers/music_state_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FocusCompanionScreen
// ConsumerStatefulWidget so it reacts to themeProvider changes (color + brightness).
// Robot eyes tint changes with the selected primary colour.
// ─────────────────────────────────────────────────────────────────────────────

class FocusCompanionScreen extends ConsumerStatefulWidget {
  const FocusCompanionScreen({super.key});

  @override
  ConsumerState<FocusCompanionScreen> createState() =>
      _FocusCompanionScreenState();
}

class _FocusCompanionScreenState extends ConsumerState<FocusCompanionScreen> {
  final _timer = FocusTimerController();
  final _camera = CameraFocusDetector();

  bool _cameraGranted = false;
  bool _sessionActive = false;
  bool _isFullscreen = false;

  int _selectedMinutes = 25;
  bool _showCustomSlider = false;
  int _customMinutes = 25;

  static const _presets = [0, 15, 25, 45, 60];

  // ── Floating tool windows ─────────────────────────────────────
  // Ordered list (last = topmost). Maps tool id → state.
  final List<FloatingToolState> _floatingTools = [];

  @override
  void initState() {
    super.initState();
    _timer.onTimerReset = () {
      if (mounted) _showResetSnackBar();
    };
    _timer.onComplete = () {
      if (mounted) _showCompleteDialog();
    };
    _camera.addListener(_onCameraUpdate);
    _checkCameraPermission();
  }

  void _onCameraUpdate() {
    if (_sessionActive) _timer.updateFocus(_camera.isFocused);
  }

  Future<void> _checkCameraPermission() async {
    final s = await Permission.camera.status;
    setState(() => _cameraGranted = s.isGranted);
  }

  Future<bool> _requestCamera() async {
    final r = await Permission.camera.request();
    setState(() => _cameraGranted = r.isGranted);
    return r.isGranted;
  }

  Future<void> _startSession() async {
    if (!_cameraGranted) {
      final ok = await _requestCamera();
      if (!ok) return;
    }
    await _camera.initialize();
    setState(() => _sessionActive = true);
    if (_selectedMinutes == 0) {
      _timer.startFree();
    } else {
      _timer.start(minutes: _selectedMinutes);
    }
  }

  void _stopSession() {
    _timer.stop();
    _camera.stop();
    // Clear all floating tool windows (especially WebViews) BEFORE rebuilding
    // the setup screen. Leaving stale WebView widgets in the tree causes a
    // black / corrupted frame when the session stack is torn down.
    _floatingTools.clear();
    // Stop any music that was playing (including YouTube WebView mode)
    ref.read(musicStateProvider.notifier).stop();
    setState(() => _sessionActive = false);
  }

  /// Fullscreen = push a new route from the ROOT navigator.
  /// This covers EVERYTHING including the bottom navigation bar.
  Future<void> _toggleFullscreen() async {
    setState(() => _isFullscreen = true);

    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        fullscreenDialog: false,
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => FocusFullscreenPage(
          timer: _timer,
          selectedMinutes: _selectedMinutes,
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );

    // Popped — restore state & system UI
    if (mounted) setState(() => _isFullscreen = false);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
  }

  void _exitFullscreen() {
    if (_isFullscreen) setState(() => _isFullscreen = false);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
  }

  void _showResetSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
          '⚠️  Too distracted — timer reset!',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        duration: 3.seconds,
      ),
    );
  }

  void _showCompleteDialog() {
    final primary = ref.read(themeProvider).primaryColor;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 140,
              height: 70,
              child: RobotEyesWidget(
                mood: FocusMood.happy,
                phase: DistractionPhase.none,
                focusedColor: primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'SESSION COMPLETE!',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You stayed focused for '
              '${_selectedMinutes == 0 ? "your session" : "$_selectedMinutes minutes"}. 🎉',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.white60, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _stopSession();
              });
            },
            child: Text(
              'DONE',
              style: GoogleFonts.outfit(
                color: primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _camera.removeListener(_onCameraUpdate);
    _timer.dispose();
    _camera.dispose();
    _exitFullscreen(); // always restore system UI on dispose
    super.dispose();
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Watch themeProvider — rebuilds automatically on color or brightness change
    final themeState = ref.watch(themeProvider);
    final primary = themeState.primaryColor;
    final isDark = themeState.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF080808)
          : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: _sessionActive
            ? _buildActiveSession(isDark, primary)
            : _buildSetup(isDark, primary),
      ),
    );
  }

  // ── SETUP SCREEN ──────────────────────────────────────────────────────────

  Widget _buildSetup(bool isDark, Color primary) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STUDY ZONE',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'Focus companion — powered by your camera',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 32),

          // Robot eyes preview — tinted with selected colour when focused
          Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.18),
                      blurRadius: 40,
                      offset: const Offset(0, 15),
                    ),
                  ],
                  border: Border.all(
                    color: primary.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(27),
                  child: RobotEyesWidget(
                    mood: FocusMood.normal,
                    phase: DistractionPhase.none,
                    focusedColor: primary, // 👁️ eyes tint = selected colour
                  ),
                ),
              )
              .animate()
              .fadeIn(delay: 200.ms)
              .scale(begin: const Offset(0.9, 0.9), curve: Curves.elasticOut),

          const SizedBox(height: 12),

          Text(
            'LOLI watches you through the camera.\n'
            'Stay focused → happy eyes. Look away → angry reset.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.grey,
              height: 1.6,
            ),
          ).animate().fadeIn(delay: 400.ms),

          const SizedBox(height: 36),

          // Duration picker
          _buildDurationPicker(isDark, primary),

          const SizedBox(height: 32),

          // Start button — uses selected primary colour
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: _contrastColor(primary),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    size: 24,
                    color: _contrastColor(primary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'START FOCUS SESSION',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontSize: 15,
                      color: _contrastColor(primary),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.3),

          const SizedBox(height: 32),

          _buildHowItWorks(isDark, primary),
        ],
      ),
    );
  }

  // Auto pick black/white text based on background luminance
  Color _contrastColor(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.35 ? Colors.black : Colors.white;
  }

  Widget _buildDurationPicker(bool isDark, Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT DURATION',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: primary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: _presets.map((mins) {
            final sel = !_showCustomSlider && _selectedMinutes == mins;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedMinutes = mins;
                  _showCustomSlider = false;
                }),
                child: AnimatedContainer(
                  duration: 200.ms,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: sel
                        ? primary.withOpacity(0.12)
                        : isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: sel
                          ? primary.withOpacity(0.6)
                          : isDark
                          ? Colors.white12
                          : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        mins == 0 ? '∞' : '$mins',
                        style: GoogleFonts.outfit(
                          fontSize: mins == 0 ? 22 : 20,
                          fontWeight: FontWeight.w900,
                          color: sel
                              ? primary
                              : isDark
                              ? Colors.white60
                              : Colors.black54,
                        ),
                      ),
                      if (mins > 0)
                        Text(
                          'min',
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            color: sel ? primary.withOpacity(0.7) : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 12),

        GestureDetector(
          onTap: () => setState(() => _showCustomSlider = !_showCustomSlider),
          child: AnimatedContainer(
            duration: 200.ms,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _showCustomSlider
                  ? primary.withOpacity(0.08)
                  : isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _showCustomSlider
                    ? primary.withOpacity(0.4)
                    : isDark
                    ? Colors.white12
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _showCustomSlider
                      ? 'CUSTOM: $_customMinutes MIN'
                      : 'CUSTOM DURATION',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _showCustomSlider ? primary : Colors.grey,
                  ),
                ),
                Icon(
                  _showCustomSlider
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.tune_rounded,
                  color: _showCustomSlider ? primary : Colors.grey,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        if (_showCustomSlider) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '1',
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: primary,
                    thumbColor: primary,
                    overlayColor: primary.withOpacity(0.1),
                    inactiveTrackColor: isDark
                        ? Colors.white12
                        : Colors.grey.shade200,
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: _customMinutes.toDouble(),
                    min: 1,
                    max: 120,
                    divisions: 119,
                    onChanged: (v) => setState(() {
                      _customMinutes = v.round();
                      _selectedMinutes = _customMinutes;
                    }),
                  ),
                ),
              ),
              Text(
                '120',
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildHowItWorks(bool isDark, Color primary) {
    const steps = [
      (
        '👁️',
        'Camera watches you',
        'Front camera detects if you\'re looking at the screen',
      ),
      (
        '⏱️',
        'Timer freezes when you look away',
        'Look away for 3s → timer pauses, eyes go curious',
      ),
      (
        '😠',
        'Eyes get angry',
        '6-9s distracted → eyes furrow and "DISTRACTED" flashes',
      ),
      (
        '🔄',
        'Timer resets if too distracted',
        '9s+ away → timer resets completely to keep you honest',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOW IT WORKS',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: primary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          ...steps.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.$1, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.$2,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          s.$3,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.grey,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 800.ms);
  }

  // ── ACTIVE SESSION ────────────────────────────────────────────────────────

  Widget _buildActiveSession(bool isDark, Color primary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate default starting positions for each tool
        final midX = (constraints.maxWidth - 320) / 2;
        final midY = constraints.maxHeight * 0.12;

        return Stack(
          children: [
            // ── Main session content ──
            ListenableBuilder(
              listenable: _timer,
              builder: (ctx, _) {
                final isDistracted =
                    _timer.phase == DistractionPhase.angry ||
                    _timer.phase == DistractionPhase.critical;
                final eyeGlowColor = isDistracted ? Colors.red : primary;

                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Top bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'FOCUS SESSION',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: primary,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                _sessionLabel,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                tooltip: _isFullscreen
                                    ? 'Exit Fullscreen'
                                    : 'Fullscreen',
                                onPressed: _toggleFullscreen,
                                icon: Icon(
                                  _isFullscreen
                                      ? Icons.fullscreen_exit_rounded
                                      : Icons.fullscreen_rounded,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black45,
                                ),
                              ),
                              IconButton(
                                onPressed: _confirmStop,
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ).animate().fadeIn(),

                      const Spacer(),

                      // Robot eyes
                      Container(
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: eyeGlowColor.withOpacity(0.22),
                              blurRadius: 50,
                              offset: const Offset(0, 20),
                            ),
                          ],
                          border: Border.all(
                            color: eyeGlowColor.withOpacity(0.15),
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(31),
                          child: RobotEyesWidget(
                            mood: _timer.mood,
                            phase: _timer.phase,
                            focusedColor: primary,
                          ),
                        ),
                      ).animate().scale(
                        begin: const Offset(0.85, 0.85),
                        curve: Curves.elasticOut,
                        duration: 800.ms,
                      ),

                      const SizedBox(height: 28),

                      _buildTimerDisplay(isDark, primary),

                      const SizedBox(height: 16),

                      if (_timer.isCountdown)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _timer.progress,
                            backgroundColor: isDark
                                ? Colors.white12
                                : Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(
                              isDistracted ? Colors.red : primary,
                            ),
                            minHeight: 6,
                          ),
                        ),

                      const SizedBox(height: 16),

                      _buildFocusStatusPill(isDark, primary),

                      const SizedBox(height: 16),

                      // Quick tools bar — hidden in fullscreen
                      if (!_isFullscreen &&
                          ref.watch(studySettingsProvider).showQuickTools)
                        StudyMiniToolsBar(
                          primary: primary,
                          isDark: isDark,
                          openTools: {
                            for (final t in _floatingTools) t.id: t.visible,
                          },
                          onToggle: (tool) => _toggleTool(
                            tool,
                            primary,
                            isDark,
                            Offset(
                              midX.clamp(0, constraints.maxWidth - 320),
                              midY.clamp(0, constraints.maxHeight - 480),
                            ),
                          ),
                        ),

                      const Spacer(),

                      _buildDistractionStats(isDark, primary),
                    ],
                  ),
                );
              },
            ),

            // ── Floating tool windows (drawn above session content) ──
            ..._floatingTools.map((tool) {
              Widget content;
              double w = 300, h = 400;

              switch (tool.id) {
                case 'google':
                  content = WebViewToolContent(
                    url: 'https://www.google.com/search?udm=50&aep=11',
                    primary: primary,
                    isDark: isDark,
                  );
                  w = 340;
                  h = 480;

                case 'music':
                  content = MusicPlayerContent(
                    primary: primary,
                    isDark: isDark,
                  );
                  w = 320;
                  h = 410;
                default:
                  content = const SizedBox.shrink();
              }

              // Clamp position to screen bounds
              final clampedPos = _clampOffset(
                tool.position,
                constraints,
                w,
                tool.minimized ? 44 : (44 + h),
              );

              return FloatingToolWindow(
                key: ValueKey(tool.id),
                state: FloatingToolState(
                  id: tool.id,
                  emoji: tool.emoji,
                  title: tool.title,
                  position: clampedPos,
                  minimized: tool.minimized,
                  visible: tool.visible,
                ),
                primary: primary,
                isDark: isDark,
                content: content,
                contentWidth: w,
                contentHeight: h,
                headerActions: null,
                onClose: () => setState(() => tool.visible = false),
                onMinimize: () =>
                    setState(() => tool.minimized = !tool.minimized),
                onDragUpdate: (newPos) => setState(() {
                  tool.position = _clampOffset(
                    newPos,
                    constraints,
                    w,
                    tool.minimized ? 44 : (44 + h),
                  );
                }),
                onTapToFront: () => setState(() {
                  _floatingTools.remove(tool);
                  _floatingTools.add(tool);
                }),
              );
            }),
          ],
        );
      },
    );
  }

  /// Toggle a tool open/close. Creates the FloatingToolState on first open.
  void _toggleTool(
    StudyTool tool,
    Color primary,
    bool isDark,
    Offset defaultPos,
  ) {
    setState(() {
      final existing = _floatingTools.where((t) => t.id == tool.id);
      if (existing.isEmpty) {
        // First open — create & push to top
        _floatingTools.add(
          FloatingToolState(
            id: tool.id,
            emoji: tool.emoji,
            title: tool.windowTitle,
            position: defaultPos,
          ),
        );
      } else {
        final t = existing.first;
        if (t.visible) {
          t.visible = false; // close
        } else {
          t.visible = true; // re-open

          // Bring to front
          _floatingTools.remove(t);
          _floatingTools.add(t);
        }
      }
    });
  }

  /// Keep floating windows within the screen area.
  Offset _clampOffset(Offset pos, BoxConstraints c, double w, double h) {
    return Offset(
      pos.dx.clamp(0.0, (c.maxWidth - w).clamp(0.0, c.maxWidth)),
      pos.dy.clamp(0.0, (c.maxHeight - h).clamp(0.0, c.maxHeight)),
    );
  }

  String get _sessionLabel =>
      _selectedMinutes == 0 ? 'Free mode' : '$_selectedMinutes min session';

  void _confirmStop() {
    final isDark = ref.read(themeProvider).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'END SESSION?',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'Your progress will be lost.',
          style: GoogleFonts.outfit(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: GoogleFonts.outfit(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              // Pop the dialog first, then stop on the next frame so the
              // dialog's pop animation completes cleanly (avoids black screen).
              Navigator.pop(context);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _stopSession();
              });
            },
            child: Text(
              'END',
              style: GoogleFonts.outfit(
                color: Colors.red,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay(bool isDark, Color primary) {
    final isDistracted =
        _timer.phase == DistractionPhase.angry ||
        _timer.phase == DistractionPhase.critical;
    final textColor = isDistracted
        ? (_timer.phase == DistractionPhase.critical
              ? Colors.red
              : Colors.orange)
        : (isDark ? Colors.white : Colors.black87);

    return AnimatedDefaultTextStyle(
      duration: 300.ms,
      style: GoogleFonts.outfit(
        fontSize: isDistracted ? 36 : 58,
        fontWeight: FontWeight.w900,
        color: textColor,
        letterSpacing: isDistracted ? 4 : -2,
      ),
      child: Text(_timer.displayTime).animate(
        key: ValueKey(_timer.phase),
        effects: isDistracted
            ? [ShakeEffect(hz: 3, curve: Curves.easeInOut, duration: 800.ms)]
            : [],
      ),
    );
  }

  Widget _buildFocusStatusPill(bool isDark, Color primary) {
    final (label, color, icon) = switch (_timer.phase) {
      DistractionPhase.none => (
        _timer.isFocused ? 'FOCUSED' : 'STARTING CAMERA...',
        _timer.isFocused ? Colors.green : Colors.grey,
        _timer.isFocused ? Icons.visibility_rounded : Icons.camera_alt_outlined,
      ),
      DistractionPhase.searching => (
        'WHERE ARE YOU?',
        Colors.amber,
        Icons.search_rounded,
      ),
      DistractionPhase.angry => (
        'DISTRACTED — TIMER FROZEN',
        Colors.orange,
        Icons.pause_circle_rounded,
      ),
      DistractionPhase.critical => (
        'VERY DISTRACTED!',
        Colors.red,
        Icons.warning_rounded,
      ),
      DistractionPhase.reset => (
        'TIMER RESET',
        Colors.red.shade300,
        Icons.refresh_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistractionStats(bool isDark, Color primary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem(
            'ELAPSED',
            '${_timer.elapsedSeconds ~/ 60}m ${_timer.elapsedSeconds % 60}s',
            Icons.timer_rounded,
            isDark,
          ),
          Container(
            width: 1,
            height: 32,
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
          _statItem(
            'STATUS',
            _moodLabel(_timer.mood),
            _timer.mood == FocusMood.happy || _timer.mood == FocusMood.normal
                ? Icons.check_circle_outline_rounded
                : Icons.warning_amber_rounded,
            isDark,
            valueColor: _moodColor(_timer.mood, primary),
          ),
          Container(
            width: 1,
            height: 32,
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
          _statItem(
            _timer.isCountdown ? 'REMAINING' : 'MODE',
            _timer.isCountdown ? '${_timer.remainingSeconds ~/ 60}m' : 'Free',
            Icons.fit_screen_rounded,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _statItem(
    String label,
    String value,
    IconData icon,
    bool isDark, {
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? Colors.white38 : Colors.grey.shade400,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 9,
            color: Colors.grey,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: valueColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  String _moodLabel(FocusMood m) => switch (m) {
    FocusMood.normal => 'ON TRACK',
    FocusMood.happy => 'GREAT!',
    FocusMood.curious => 'CURIOUS',
    FocusMood.angry => 'ANGRY',
    FocusMood.tired => 'TIRED',
  };

  Color _moodColor(FocusMood m, Color primary) => switch (m) {
    FocusMood.normal => primary, // ← uses selected colour
    FocusMood.happy => primary, // ← uses selected colour
    FocusMood.curious => Colors.amber,
    FocusMood.angry => Colors.orange,
    FocusMood.tired => Colors.red.shade300,
  };
}

// Extension helpers
extension on int {
  Duration get ms => Duration(milliseconds: this);
  Duration get seconds => Duration(seconds: this);
}
