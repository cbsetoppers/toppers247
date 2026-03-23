import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/settings_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ChatScreen  —  Full-screen AI Chatbot WebView (no header/appbar).
// The default AI is read from SharedPreferences ('study_default_ai_bot').
// The preference is shared with profile settings and quick tools.
// ─────────────────────────────────────────────────────────────────────────────

const _prefKey = 'study_default_ai_bot';

const _bots = [
  _BotEntry('google',   '🔍', 'Search',   'https://www.google.com/search?udm=50&aep=11', null),
  _BotEntry('gemini',   '⭐', 'Gemini',    'https://gemini.google.com/app?hl=en-IN', 'assets/gemini.png'),
  _BotEntry('chatgpt',  '🤖', 'ChatGPT',   'https://chatgpt.com/', 'assets/chatgpt.png'),
  _BotEntry('deepseek', '🧠', 'DeepSeek',  'https://chat.deepseek.com/', 'assets/deepseek.png'),
];

class _BotEntry {
  final String id;
  final String emoji;
  final String name;
  final String url;
  final String? asset;
  const _BotEntry(this.id, this.emoji, this.name, this.url, this.asset);
}

class ChatScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const ChatScreen({super.key, this.onBack});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late WebViewController _wvc;
  bool   _loading = true;
  String _botId   = 'deepseek';
  bool   _ready   = false;

  // ── Floating Button Animation/State ──
  Offset? _fabPos;

  @override
  void initState() {
    super.initState();
    _loadPref();
  }

  Future<void> _loadPref() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey) ?? 'deepseek';
    if (!mounted) return;
    setState(() { _botId = saved; _ready = true; });
    _initWebView(saved);
  }

  void _initWebView(String botId) {
    final bot = _bots.firstWhere((b) => b.id == botId);
    _wvc = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onNavigationRequest: (_) => NavigationDecision.navigate,
      ))
      ..loadRequest(Uri.parse(bot.url));

    _configureAndroid();
  }

  /// Configure Android-specific settings for file upload + autoplay.
  void _configureAndroid() {
    final platform = _wvc.platform;
    if (platform is AndroidWebViewController) {
      // ── File chooser ──────────────────────────────────────────────────────
      // Uses FilePicker which handles storage permissions automatically.
      // Returns file:// paths; for API 30+ content URIs are preferred but
      // file paths still work when the app has MANAGE_EXTERNAL_STORAGE or
      // READ_MEDIA_* permissions (declared in AndroidManifest).
      platform.setOnShowFileSelector((FileSelectorParams params) async {
        try {
          FileType fileType = FileType.any;
          // Honour the MIME type hint if provided
          if (params.acceptTypes.isNotEmpty) {
            final mime = params.acceptTypes.first.toLowerCase();
            if (mime.startsWith('image/')) {
              fileType = FileType.image;
            } else if (mime.startsWith('video/')) {
              fileType = FileType.video;
            } else if (mime.startsWith('audio/')) {
              fileType = FileType.audio;
            }
          }

          final result = await FilePicker.platform.pickFiles(
            type: fileType,
            allowMultiple: params.mode == FileSelectorMode.openMultiple,
            withData: false,        // Don't read bytes, just path
            withReadStream: false,
          );

          if (result != null) {
            // Convert file paths to content:// URIs on Android for API 30+
            final paths = result.files
                .where((f) => f.path != null && File(f.path!).existsSync())
                .map((f) {
                  final path = f.path!;
                  // Return file:// URI — content:// requires MediaStore which
                  // FilePicker doesn't expose directly; file:// works with
                  // READ_EXTERNAL_STORAGE / READ_MEDIA_* permissions.
                  return 'file://$path';
                })
                .toList();
            if (paths.isNotEmpty) return paths;
          }
        } catch (e) {
          debugPrint('[ChatScreen] File picker error: $e');
        }
        return [];
      });

      // Allow autoplay (needed for voice features in ChatGPT / Gemini)
      platform.setMediaPlaybackRequiresUserGesture(false);

      // ── Microphone & Permissions (Bypass static check) ────────────────────
      try {
        (platform as dynamic).setOnPermissionRequest((dynamic request) async {
          final List<String> resources = (request.resources as List).cast<String>();
          if (resources.contains('android.webkit.resource.AUDIO_CAPTURE')) {
            await Permission.microphone.request();
          }
          request.grant(resources);
        });
      } catch (_) {}
    }
  }

  void _switchBot(String id) {
    if (id == _botId) return;
    final bot = _bots.firstWhere((b) => b.id == id);
    setState(() { _botId = id; _loading = true; });
    // Persist so next open uses same bot
    SharedPreferences.getInstance().then((p) {
      p.setString(_prefKey, id);
      p.setString('main_ai_bot_pref', id);
    });
    _wvc.loadRequest(Uri.parse(bot.url));
  }

  @override
  Widget build(BuildContext context) {
    // ── Listen to global choice changes ──────────────────────────────────────
    // If user changes the default AI in Profile, we switch immediately.
    ref.listen(studySettingsProvider, (prev, next) {
      if (prev?.defaultAiBot != next.defaultAiBot && _ready) {
        _switchBot(next.defaultAiBot);
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _ready
            ? SafeArea(
                bottom: false,
                child: Stack(
                  children: [
                    WebViewWidget(controller: _wvc),
                    if (_loading)
                      const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),

                    // ── Draggable Floating Go Back Button ────────────────────
                    _buildFloatingBackButton(),
                  ],
                ),
              )
            : const Center(
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2)),
      ),
    );
  }

  Widget _buildFloatingBackButton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Initial position if not set
        _fabPos ??= Offset(constraints.maxWidth - 70, constraints.maxHeight - 100);

        return Positioned(
          left: _fabPos!.dx,
          top: _fabPos!.dy,
          child: GestureDetector(
            onPanUpdate: (d) {
              setState(() {
                _fabPos = Offset(
                  (_fabPos!.dx + d.delta.dx).clamp(10, constraints.maxWidth - 60),
                  (_fabPos!.dy + d.delta.dy).clamp(10, constraints.maxHeight - 60),
                );
              });
            },
            onTap: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white38, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 15,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

