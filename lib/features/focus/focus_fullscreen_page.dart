import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';


import '../../providers/theme_provider.dart';
import 'focus_models.dart';
import 'focus_timer_controller.dart';
import 'robot_eyes_widget.dart';
import 'study_mini_tools.dart';
import '../../providers/settings_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FocusFullscreenPage
//
// Pushed via root navigator → covers the ENTIRE screen including the bottom
// navigation bar. The session timer & camera are shared references so they
// keep running seamlessly when switching to/from full screen mode.
// ─────────────────────────────────────────────────────────────────────────────

class FocusFullscreenPage extends ConsumerStatefulWidget {
  final FocusTimerController timer;
  final int selectedMinutes;

  const FocusFullscreenPage({
    super.key,
    required this.timer,
    required this.selectedMinutes,
  });

  @override
  ConsumerState<FocusFullscreenPage> createState() =>
      _FocusFullscreenPageState();
}

class _FocusFullscreenPageState extends ConsumerState<FocusFullscreenPage> {
  // Each fullscreen page has its own floating tool list (independent of
  // the normal session — tools start fresh in fullscreen mode).
  final List<FloatingToolState> _floatingTools = [];

  @override
  void initState() {
    super.initState();
    // Hide system UI immediately on enter
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Hide system UI immediately on enter
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Always restore system UI when leaving fullscreen
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _exit() => Navigator.of(context).pop();

  String get _sessionLabel =>
      widget.selectedMinutes == 0
          ? 'Free mode'
          : '${widget.selectedMinutes} min session';

  void _toggleTool(
      StudyTool tool, Color primary, bool isDark, Offset defaultPos) {
    setState(() {
      final existing =
          _floatingTools.where((t) => t.id == tool.id).toList();
      if (existing.isEmpty) {
        _floatingTools.add(FloatingToolState(
          id: tool.id,
          emoji: tool.emoji,
          title: tool.windowTitle,
          position: defaultPos,
        ));
      } else {
        final t = existing.first;
        if (t.visible) {
          t.visible = false;
        } else {
          t.visible = true;
          _floatingTools.remove(t);
          _floatingTools.add(t);
        }
      }
    });
  }

  Offset _clamp(Offset pos, BoxConstraints c, double w, double h) => Offset(
        pos.dx.clamp(0.0, (c.maxWidth - w).clamp(0.0, c.maxWidth)),
        pos.dy.clamp(0.0, (c.maxHeight - h).clamp(0.0, c.maxHeight)),
      );

  @override
  Widget build(BuildContext context) {
    final theme   = ref.watch(themeProvider);
    final primary = theme.primaryColor;
    final isDark  = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final cx = (constraints.maxWidth - 320) / 2;
          final cy = constraints.maxHeight * 0.08;

          return Stack(
            children: [
              // ── Session content ──────────────────────────────────────────
              ListenableBuilder(
                listenable: widget.timer,
                builder: (ctx, _) {
                  final isDistracted =
                      widget.timer.phase == DistractionPhase.angry ||
                          widget.timer.phase == DistractionPhase.critical;
                  final glowColor = isDistracted ? Colors.red : primary;

                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Column(
                        children: [
                          // ── Top bar ──────────────────────────────────────
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('FOCUS SESSION',
                                      style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: primary,
                                          letterSpacing: 2)),
                                  Text(_sessionLabel,
                                      style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: isDark ? Colors.white38 : Colors.black38,
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                              // Exit fullscreen
                              GestureDetector(
                                onTap: _exit,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                        color: isDark ? Colors.white12 : Colors.black12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                          Icons.fullscreen_exit_rounded,
                                          color: Colors.white60,
                                          size: 16),
                                      const SizedBox(width: 6),
                                      Text('EXIT',
                                          style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? Colors.white60 : Colors.black54,
                                              letterSpacing: 1.5)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ).animate().fadeIn(),

                          const Spacer(),

                          // ── Robot eyes ───────────────────────────────────
                          Container(
                            width: double.infinity,
                            height: constraints.maxHeight * 0.28,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black : Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                    color: glowColor.withOpacity(0.25),
                                    blurRadius: 60,
                                    offset: const Offset(0, 20)),
                              ],
                              border: Border.all(
                                  color: glowColor.withOpacity(0.18),
                                  width: 1.5),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(31),
                              child: RobotEyesWidget(
                                mood: widget.timer.mood,
                                phase: widget.timer.phase,
                                focusedColor: primary,
                              ),
                            ),
                          ).animate().scale(
                              begin: const Offset(0.85, 0.85),
                              curve: Curves.elasticOut,
                              duration: Duration(milliseconds: 800)),

                          const SizedBox(height: 24),

                          // ── Timer ────────────────────────────────────────
                          _buildTimer(isDistracted, primary, isDark),

                          const SizedBox(height: 14),

                          // ── Progress bar ─────────────────────────────────
                          if (widget.timer.isCountdown)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: widget.timer.progress,
                                backgroundColor: Colors.white10,
                                valueColor: AlwaysStoppedAnimation(
                                    isDistracted ? Colors.red : primary),
                                minHeight: 5,
                              ),
                            ),

                          const SizedBox(height: 14),

                          // ── Status pill ──────────────────────────────────
                          _buildStatusPill(primary),

                          const SizedBox(height: 16),

                          // ── Quick tools bar ──────────────────────────────
                          if (ref.watch(studySettingsProvider).showQuickTools)
                            StudyMiniToolsBar(
                              primary: primary,
                              isDark: isDark,
                              openTools: {
                                for (final t in _floatingTools)
                                  t.id: t.visible,
                              },
                              onToggle: (tool) => _toggleTool(
                                tool,
                                primary,
                                isDark,
                                Offset(
                                  cx.clamp(0, constraints.maxWidth - 320),
                                  cy.clamp(0, constraints.maxHeight - 480),
                                ),
                              ),
                            ),

                          const Spacer(),

                          _buildStats(primary, isDark),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // ── Floating tool windows ────────────────────────────────────
              ..._floatingTools.map((tool) {
                Widget content;
                double w = 300, h = 400;

                switch (tool.id) {
                  case 'google':
                    content = WebViewToolContent(
                        url: 'https://www.google.com/search?udm=50&aep=11',
                        primary: primary, isDark: isDark);
                    w = 340; h = 480;

                  case 'music':
                    content = MusicPlayerContent(
                        primary: primary, isDark: isDark);
                    w = 320; h = 410;
                  default:
                    content = const SizedBox.shrink();
                }

                final clampedPos = _clamp(
                    tool.position,
                    constraints,
                    w,
                    tool.minimized ? 44 : (44 + h));

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
                  onClose: () =>
                      setState(() => tool.visible = false),
                  onMinimize: () =>
                      setState(() => tool.minimized = !tool.minimized),
                  onDragUpdate: (newPos) => setState(() {
                    tool.position = _clamp(newPos, constraints, w,
                        tool.minimized ? 44 : (44 + h));
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
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────

  Widget _buildTimer(bool isDistracted, Color primary, bool isDark) {
    final textColor = isDistracted
        ? (widget.timer.phase == DistractionPhase.critical
            ? Colors.red
            : Colors.orange)
        : (isDark ? Colors.white : Colors.black);

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      style: GoogleFonts.outfit(
          fontSize: isDistracted ? 36 : 58,
          fontWeight: FontWeight.w900,
          color: textColor,
          letterSpacing: isDistracted ? 4 : -2),
      child: Text(widget.timer.displayTime).animate(
        key: ValueKey(widget.timer.phase),
        effects: isDistracted
            ? [
                ShakeEffect(
                    hz: 3,
                    curve: Curves.easeInOut,
                    duration: const Duration(milliseconds: 800))
              ]
            : [],
      ),
    );
  }

  Widget _buildStatusPill(Color primary) {
    final (label, color, icon) = switch (widget.timer.phase) {
      DistractionPhase.none => (
          widget.timer.isFocused ? 'FOCUSED' : 'STARTING CAMERA...',
          widget.timer.isFocused ? Colors.green : Colors.grey,
          widget.timer.isFocused
              ? Icons.visibility_rounded
              : Icons.camera_alt_outlined,
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: 1.5)),
        ],
      ),
    );
  }

  Widget _buildStats(Color primary, bool isDark) {
    final t = widget.timer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statCell('ELAPSED',
              '${t.elapsedSeconds ~/ 60}m ${t.elapsedSeconds % 60}s',
              Icons.timer_rounded, primary, isDark),
          Container(width: 1, height: 28, color: isDark ? Colors.white10 : Colors.black12),
          _statCell('STATUS', _moodLabel(t.mood),
              t.mood == FocusMood.happy || t.mood == FocusMood.normal
                  ? Icons.check_circle_outline_rounded
                  : Icons.warning_amber_rounded,
              _moodColor(t.mood, primary), isDark),
          Container(width: 1, height: 28, color: isDark ? Colors.white10 : Colors.black12),
          _statCell(
              t.isCountdown ? 'REMAINING' : 'MODE',
              t.isCountdown ? '${t.remainingSeconds ~/ 60}m' : 'Free',
              Icons.fit_screen_rounded,
              primary, isDark),
        ],
      ),
    );
  }

  Widget _statCell(String label, String value, IconData icon, Color color, bool isDark) {
    return Column(
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.white30 : Colors.black26),
        const SizedBox(height: 3),
        Text(label,
            style: GoogleFonts.outfit(
                fontSize: 9,
                color: isDark ? Colors.white38 : Colors.black38,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: color)),
      ],
    );
  }

  String _moodLabel(FocusMood m) => switch (m) {
        FocusMood.normal  => 'ON TRACK',
        FocusMood.happy   => 'GREAT!',
        FocusMood.curious => 'CURIOUS',
        FocusMood.angry   => 'ANGRY',
        FocusMood.tired   => 'TIRED',
      };

  Color _moodColor(FocusMood m, Color primary) => switch (m) {
        FocusMood.normal  => primary,
        FocusMood.happy   => primary,
        FocusMood.curious => Colors.amber,
        FocusMood.angry   => Colors.orange,
        FocusMood.tired   => Colors.red.shade300,
      };
}
