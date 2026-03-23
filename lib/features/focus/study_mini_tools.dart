import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/music_state_provider.dart';

// Tools (in order): Google | Music
// ─────────────────────────────────────────────────────────────────────────────

// ── Model ─────────────────────────────────────────────────────────────────────

class FloatingToolState {
  final String id;
  final String emoji;
  final String title;
  Offset position;
  bool minimized;
  bool visible;

  FloatingToolState({
    required this.id,
    required this.emoji,
    required this.title,
    required this.position,
    this.minimized = false,
    this.visible = true,
  });
}

// ── Enum ─────────────────────────────────────────────────────────────────────

enum StudyTool { google, music }

extension StudyToolProps on StudyTool {
  String get id => name;
  String get emoji => switch (this) {
    StudyTool.google => '🔍',
    StudyTool.music => '🎵',
  };
  String get label => switch (this) {
    StudyTool.google => 'Google',
    StudyTool.music => 'Music',
  };
  String get windowTitle => switch (this) {
    StudyTool.google => 'Google Search',
    StudyTool.music => 'Study Music 🎵',
  };
}

// ── Android WebView helper (file-chooser + user-agent + autoplay) ─────────────

/// Apply Android-specific settings to any [WebViewController]:
/// • Intercepts "Choose File" dialogs in websites → opens system file picker
/// • Sets a desktop-class Chrome User-Agent so login pages don't redirect
/// • Disables the "requires user gesture" guard on media autoplay
void configureAndroidWebView(
  WebViewController controller, {
  FileType defaultFileType = FileType.any,
}) {
  final platform = controller.platform;
  if (platform is AndroidWebViewController) {
    // ── File chooser ──────────────────────────────────────────────────────
    // Intercepts "Choose File" / "Upload" buttons in websites.
    platform.setOnShowFileSelector((FileSelectorParams params) async {
      try {
        FileType type = defaultFileType;

        // If the website provides hints (e.g. image/*), filter the picker
        if (params.acceptTypes.isNotEmpty) {
          final mime = params.acceptTypes.first.toLowerCase();
          if (mime.startsWith('image/')) {
            type = FileType.image;
          } else if (mime.startsWith('video/')) {
            type = FileType.video;
          } else if (mime.startsWith('audio/')) {
            type = FileType.audio;
          }
        }

        final result = await FilePicker.platform.pickFiles(
          type: type,
          allowMultiple: params.mode == FileSelectorMode.openMultiple,
        );

        if (result != null) {
          final paths = result.files
              .where((f) => f.path != null)
              .map((f) => 'file://${f.path!}') // Some AIs expect file:// scheme
              .toList();
          if (paths.isNotEmpty) return paths;
        }
      } catch (e) {
        debugPrint('[WebView] File picking failed: $e');
      }
      return [];
    });

    // Allow media autoplay (needed for YouTube, voice features, etc.)
    platform.setMediaPlaybackRequiresUserGesture(false);
  }
}

// ── Quick Tools Bar ────────────────────────────────────────────────────────────

class StudyMiniToolsBar extends ConsumerWidget {
  final Color primary;
  final bool isDark;
  final Map<String, bool> openTools;
  final ValueChanged<StudyTool> onToggle;

  const StudyMiniToolsBar({
    super.key,
    required this.primary,
    required this.isDark,
    required this.openTools,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final music = ref.watch(musicStateProvider);
    final musicNotifier = ref.read(musicStateProvider.notifier);
    final hasMusic = music.mode != MusicMode.none;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'QUICK TOOLS',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: primary,
              letterSpacing: 2,
            ),
          ),
        ),
        Row(
          children: StudyTool.values.map((tool) {
            final isOpen = openTools[tool.id] ?? false;
            return Expanded(
              child: GestureDetector(
                onTap: () => onToggle(tool),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? primary.withOpacity(0.15)
                        : isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOpen
                          ? primary.withOpacity(0.5)
                          : isDark
                          ? Colors.white10
                          : Colors.grey.shade100,
                      width: isOpen ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isOpen
                            ? primary.withOpacity(0.12)
                            : Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(tool.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(
                        tool.label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isOpen
                              ? primary
                              : isDark
                              ? Colors.white70
                              : Colors.black54,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // ── Persistent Mini Player (below Quick Tools) ──
        if (hasMusic) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? primary.withOpacity(0.10)
                  : primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primary.withOpacity(0.25)),
            ),
            child: music.mode == MusicMode.youtubeWebView
                ? _buildWebViewMiniBar(
                    music: music,
                    musicNotifier: musicNotifier,
                    primary: primary,
                    isDark: isDark,
                  )
                : _buildAudioMiniBar(
                    music: music,
                    musicNotifier: musicNotifier,
                    primary: primary,
                    isDark: isDark,
                  ),
          ),
        ],
      ],
    );
  }
}

// ── Helpers for the mini bar ──────────────────────────────────────────────────

Widget _buildWebViewMiniBar({
  required MusicState music,
  required MusicNotifier musicNotifier,
  required Color primary,
  required bool isDark,
}) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('▶', style: TextStyle(fontSize: 14)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'YOUTUBE MUSIC',
              style: GoogleFonts.outfit(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: primary,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(
              height: 18,
              child: _MarqueeText(
                text: music.title.isEmpty
                    ? 'Playing in music tool'
                    : music.title,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: () => musicNotifier.clearWebViewMode(),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.stop_rounded, size: 16, color: Colors.red),
        ),
      ),
    ],
  );
}

Widget _buildAudioMiniBar({
  required MusicState music,
  required MusicNotifier musicNotifier,
  required Color primary,
  required bool isDark,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  music.mode == MusicMode.local
                      ? 'LOCAL MUSIC'
                      : 'YOUTUBE AUDIO',
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: primary,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(
                  height: 18,
                  child: _MarqueeText(
                    text: music.title,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _MiniCtrl(icon: Icons.skip_previous_rounded, onTap: () {}),
          const SizedBox(width: 6),
          _MiniCtrl(
            icon: music.isPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            isMain: true,
            primary: primary,
            onTap: () => music.isPlaying
                ? musicNotifier.pause()
                : musicNotifier.resume(),
          ),
          const SizedBox(width: 6),
          _MiniCtrl(icon: Icons.skip_next_rounded, onTap: () {}),
        ],
      ),
      const SizedBox(height: 6),
      // Thin seekable progress bar
      ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: music.duration.inSeconds > 0
              ? (music.position.inSeconds / music.duration.inSeconds).clamp(
                  0.0,
                  1.0,
                )
              : 0.0,
          minHeight: 2,
          backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation(primary),
        ),
      ),
    ],
  );
}

class _MiniCtrl extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isMain;
  final Color? primary;

  const _MiniCtrl({
    required this.icon,
    required this.onTap,
    this.isMain = false,
    this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isMain ? 32 : 28,
        height: isMain ? 32 : 28,
        decoration: BoxDecoration(
          color: isMain ? (primary ?? Colors.blue).withOpacity(0.15) : null,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: isMain ? 20 : 18,
          color: isMain ? primary : Colors.grey.shade500,
        ),
      ),
    );
  }
}

// ── Floating Tool Window ───────────────────────────────────────────────────────

class FloatingToolWindow extends StatelessWidget {
  final FloatingToolState state;
  final Color primary;
  final bool isDark;
  final Widget content;
  final double contentWidth;
  final double contentHeight;
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onTapToFront;
  final Widget? headerActions;

  const FloatingToolWindow({
    super.key,
    required this.state,
    required this.primary,
    required this.isDark,
    required this.content,
    required this.contentWidth,
    required this.contentHeight,
    required this.onClose,
    required this.onMinimize,
    required this.onDragUpdate,
    required this.onTapToFront,
    this.headerActions,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF141416) : Colors.white;
    const barH = 44.0;
    final totalH = state.minimized ? barH : barH + contentHeight;

    return Positioned(
      left: state.position.dx,
      top: state.position.dy,
      child: Offstage(
        offstage: !state.visible,
        child: IgnorePointer(
          ignoring: !state.visible,
          child: GestureDetector(
            onTap: onTapToFront,
            child: Material(
              color: Colors.transparent,
              elevation: state.visible ? 20 : 0,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: contentWidth,
                height: totalH,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: primary.withOpacity(0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Column(
                    children: [
                      // ── Title bar (drag handle) ──
                      GestureDetector(
                        onPanUpdate: (d) =>
                            onDragUpdate(state.position + d.delta),
                        child: Container(
                          height: barH,
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.12),
                            border: Border(
                              bottom: BorderSide(
                                color: primary.withOpacity(0.15),
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Text(
                                  state.emoji,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    state.title,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                if (headerActions != null) ...[
                                  headerActions!,
                                  const SizedBox(width: 8),
                                ],
                                Icon(
                                  Icons.drag_indicator_rounded,
                                  size: 16,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(width: 4),
                                _TitleBarBtn(
                                  icon: state.minimized
                                      ? Icons.keyboard_arrow_down_rounded
                                      : Icons.keyboard_arrow_up_rounded,
                                  color: Colors.amber,
                                  onTap: onMinimize,
                                ),
                                const SizedBox(width: 4),
                                _TitleBarBtn(
                                  icon: Icons.close_rounded,
                                  color: Colors.red,
                                  onTap: onClose,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // ── Content ──
                      Expanded(
                        child: Offstage(
                          offstage: state.minimized,
                          child: content,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleBarBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TitleBarBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 13, color: color),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 🔍  GOOGLE WEBVIEW (with file-chooser support)
// ─────────────────────────────────────────────────────────────────────────────

class WebViewToolContent extends StatefulWidget {
  final String url;
  final Color primary;
  final bool isDark;

  const WebViewToolContent({
    super.key,
    required this.url,
    required this.primary,
    required this.isDark,
  });

  @override
  State<WebViewToolContent> createState() => _WebViewToolContentState();
}

class _WebViewToolContentState extends State<WebViewToolContent> {
  late final WebViewController _wvc;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _wvc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    configureAndroidWebView(_wvc);
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      WebViewWidget(controller: _wvc),
      if (_loading)
        Center(
          child: CircularProgressIndicator(
            color: widget.primary,
            strokeWidth: 2,
          ),
        ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 🎵  MUSIC PLAYER  (local MP3  OR  YouTube / YouTube Music via WebView)
// ─────────────────────────────────────────────────────────────────────────────

class MusicPlayerContent extends ConsumerStatefulWidget {
  final Color primary;
  final bool isDark;

  const MusicPlayerContent({
    super.key,
    required this.primary,
    required this.isDark,
  });

  @override
  ConsumerState<MusicPlayerContent> createState() => _MusicPlayerContentState();
}

class _MusicPlayerContentState extends ConsumerState<MusicPlayerContent> {
  bool _fetching = false;
  final _urlCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _fetching = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;
        await ref.read(musicStateProvider.notifier).playLocal(path, name);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _fetching = false);
    }
  }

  /// Opens YouTube / YouTube Music URL directly in an embedded WebView.
  /// More reliable than audio stream extraction (no bot-protection issues).
  void _openYouTubeWebView() {
    var input = _urlCtrl.text.trim();
    if (input.isEmpty) {
      setState(() => _error = 'Please enter a YouTube or YouTube Music URL');
      return;
    }

    // Normalise: ensure it's a complete URL
    if (!input.startsWith('http')) {
      input = 'https://www.youtube.com/watch?v=$input';
    }

    // Derive a friendly title from the URL
    String title = 'YouTube Music';
    final uri = Uri.tryParse(input);
    if (uri != null) {
      if (uri.host.contains('music.youtube.com')) {
        title = 'YouTube Music';
      } else if (uri.queryParameters.containsKey('v')) {
        title = 'YouTube · ${uri.queryParameters["v"]}';
      }
    }

    ref.read(musicStateProvider.notifier).setWebViewMode(input, title);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? "${d.inHours}:" : ""}$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final music = ref.watch(musicStateProvider);
    return switch (music.mode) {
      MusicMode.none => _buildPicker(),
      MusicMode.local => _buildLocalPlayer(),
      MusicMode.youtube => _buildYouTube(),
      MusicMode.youtubeWebView => _buildYouTubeWebViewPlayer(),
    };
  }

  // ── Picker ─────────────────────────────────────────────────────────

  Widget _buildPicker() {
    final bg = widget.isDark ? const Color(0xFF141416) : Colors.white;
    final card = widget.isDark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFF2F2F7);
    final txtC = widget.isDark ? Colors.white : Colors.black;

    return Container(
      color: bg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Choose local file
          GestureDetector(
            onTap: _fetching ? null : _pickFile,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: widget.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: widget.primary.withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  _fetching
                      ? CircularProgressIndicator(
                          color: widget.primary,
                          strokeWidth: 2,
                        )
                      : const Text('📂', style: TextStyle(fontSize: 28)),
                  const SizedBox(height: 8),
                  Text(
                    'Choose MP3 from Library',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: widget.primary,
                    ),
                  ),
                  Text(
                    'Tap to open file manager',
                    style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade700)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade700)),
            ],
          ),
          const SizedBox(height: 16),

          // YouTube URL input
          Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.primary.withOpacity(0.2)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              controller: _urlCtrl,
              style: GoogleFonts.outfit(fontSize: 13, color: txtC),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Paste YouTube or YouTube Music URL…',
                hintStyle: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                prefixIcon: const Text('🎬', style: TextStyle(fontSize: 18)),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          ElevatedButton.icon(
            onPressed: _openYouTubeWebView,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(
              'Open in Music Player',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),

          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Text('✅', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Plays directly — no extraction errors!',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: Colors.green.shade400,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: Colors.red.shade400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  // ── Local player ────────────────────────────────────────────────────

  Widget _buildLocalPlayer() {
    final music = ref.watch(musicStateProvider);
    final notifier = ref.read(musicStateProvider.notifier);

    final bg = widget.isDark ? const Color(0xFF141416) : Colors.white;
    final card = widget.isDark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFF2F2F7);
    final txtC = widget.isDark ? Colors.white : Colors.black;
    final progress = music.duration.inSeconds > 0
        ? music.position.inSeconds / music.duration.inSeconds
        : 0.0;

    return Container(
      color: bg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Song name
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text('🎵', style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    music.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: txtC,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Progress slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: widget.primary,
              thumbColor: widget.primary,
              overlayColor: widget.primary.withOpacity(0.15),
              inactiveTrackColor: widget.isDark
                  ? Colors.white12
                  : Colors.grey.shade200,
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (v) {
                final pos = Duration(
                  seconds: (v * music.duration.inSeconds).round(),
                );
                notifier.seek(pos);
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _fmt(music.position),
                  style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey),
                ),
                Text(
                  _fmt(music.duration),
                  style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Stop
              _CtrlBtn(
                icon: Icons.stop_rounded,
                color: Colors.grey,
                size: 40,
                onTap: () => notifier.stop(),
              ),
              const SizedBox(width: 20),
              // Play / Pause
              _CtrlBtn(
                icon: music.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: widget.primary,
                size: 54,
                onTap: () async {
                  if (music.isPlaying) {
                    await notifier.pause();
                  } else {
                    await notifier.resume();
                  }
                },
              ),
              const SizedBox(width: 20),
              // Restart
              _CtrlBtn(
                icon: Icons.replay_rounded,
                color: Colors.grey,
                size: 40,
                onTap: () => notifier.seek(Duration.zero),
              ),
            ],
          ),

          const Spacer(),

          // Change source
          TextButton.icon(
            onPressed: () {
              notifier.stop();
            },
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: Text(
              'Change Source',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ── YouTube Audio Player UI (legacy — unused, kept for reference) ──────────

  Widget _buildYouTube() {
    // Legacy path — just fall back to WebView approach
    return _buildYouTubeWebViewPlayer();
  }

  // ── YouTube WebView Player ──────────────────────────────────────────────────

  Widget _buildYouTubeWebViewPlayer() {
    final music = ref.watch(musicStateProvider);
    final notifier = ref.read(musicStateProvider.notifier);
    final bg = widget.isDark ? const Color(0xFF141416) : Colors.white;
    final url = music.webViewUrl ?? 'https://music.youtube.com';

    return Container(
      color: bg,
      child: Column(
        children: [
          // ── Header bar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.07),
              border: Border(
                bottom: BorderSide(color: Colors.red.withOpacity(0.12)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Text('🎬', style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        music.title.isEmpty ? 'YouTube Music' : music.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Playing via YouTube WebView',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => notifier.clearWebViewMode(),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                  label: Text(
                    'Change',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),

          // ── Embedded WebView ──
          Expanded(
            child: _YTWebViewPlayer(url: url, isDark: widget.isDark),
          ),
        ],
      ),
    );
  }
}

// ── YouTube WebView Player Widget ─────────────────────────────────────────────

class _YTWebViewPlayer extends StatefulWidget {
  final String url;
  final bool isDark;

  const _YTWebViewPlayer({required this.url, required this.isDark});

  @override
  State<_YTWebViewPlayer> createState() => _YTWebViewPlayerState();
}

class _YTWebViewPlayerState extends State<_YTWebViewPlayer> {
  late WebViewController _wvc;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initController(widget.url);
  }

  @override
  void didUpdateWidget(_YTWebViewPlayer old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _wvc.loadRequest(Uri.parse(widget.url));
    }
  }

  void _initController(String url) {
    _wvc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (_) => NavigationDecision.navigate,
        ),
      )
      ..loadRequest(Uri.parse(url));

    configureAndroidWebView(_wvc);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _wvc),
        if (_loading)
          Container(
            color: widget.isDark ? const Color(0xFF141416) : Colors.white,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🎵', style: TextStyle(fontSize: 32)),
                  SizedBox(height: 12),
                  CircularProgressIndicator(strokeWidth: 2),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Small round control button ────────────────────────────────────────────────

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _CtrlBtn({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    ),
  );
}
// ── Scrolling Marquee Text ──────────────────────────────────────────────────

class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeText({required this.text, required this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> {
  late ScrollController _ctrl;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() {
    if (!_ctrl.hasClients) return;
    final max = _ctrl.position.maxScrollExtent;
    if (max <= 0) return;

    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_ctrl.hasClients) return;
      double newOffset = _ctrl.offset + 1.0;
      if (newOffset >= _ctrl.position.maxScrollExtent) {
        newOffset = 0;
      }
      _ctrl.jumpTo(newOffset);
    });
  }

  @override
  void didUpdateWidget(_MarqueeText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _timer?.cancel();
      _ctrl.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _ctrl,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          Text(widget.text, style: widget.style),
          // Add gap and duplicate for seamless loop if needed
          const SizedBox(width: 80),
          Text(widget.text, style: widget.style),
        ],
      ),
    );
  }
}
