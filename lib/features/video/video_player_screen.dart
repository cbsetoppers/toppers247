import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/youtube_service.dart';

enum VideoFit { contain, cover, fill }
enum _GestureType { none, brightness, volume }

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> with WidgetsBindingObserver {
  // Core player
  VideoPlayerController? _vpc;
  YTVideoInfo? _info;
  VideoQuality? _quality;
  bool _loading = true;
  String? _error;

  // UI visibility
  bool _showControls = true;
  bool _isFullscreen = false;
  Timer? _hideTimer;

  // Playback settings
  double _speed = 1.0;
  VideoFit _fit = VideoFit.contain;

  // Gesture tracking
  double _brightness = 0.5;
  double _volume = 0.5;
  _GestureType _gestureType = _GestureType.none;
  double _gestureStartY = 0;
  double _gestureStartVal = 0;
  bool _gestureIsLeft = false;
  Timer? _gestureHideTimer;

  // Seek feedback overlay
  bool _showSeekFeedback = false;
  bool _seekForward = true;
  int _seekSeconds = 10;
  Timer? _seekFeedbackTimer;

  // Screen lock
  bool _locked = false;
  bool _showLockFlash = false;

  @override
  void initState() {
    super.initState();
    // Hide status bar when video player screen is entered
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _initGestureSensors();
    _loadVideo();
  }

  Future<void> _initGestureSensors() async {
    try {
      _brightness = await ScreenBrightness().current;
    } catch (_) {}
    try {
      VolumeController().listener((v) {
        if (mounted) setState(() => _volume = v);
      });
      _volume = await VolumeController().getVolume();
    } catch (_) {}
  }

  Future<void> _loadVideo({VideoQuality? quality}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    Duration? savedPosition;
    if (_vpc != null && quality != null) {
      savedPosition = _vpc!.value.position;
    }

    await _vpc?.dispose();
    _vpc = null;

    try {
      if (quality == null) {
        _info = await YoutubeService.getInfo(widget.videoUrl);
      }
      final q = quality ?? _info!.qualities.first;

      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(q.url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      await ctrl.initialize();

      if (savedPosition != null) {
        await ctrl.seekTo(savedPosition);
      }

      ctrl.setPlaybackSpeed(_speed);
      ctrl.play();
      ctrl.addListener(() {
        if (mounted) setState(() {});
      });

      if (mounted) {
        setState(() {
          _quality = q;
          _vpc = ctrl;
          _loading = false;
        });
        _startHideTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);

    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    // Maintain immersive mode regardless of orientation in this screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _keepControlsVisible();
  }

  void _onBack() {
    if (_isFullscreen) {
      setState(() => _isFullscreen = false);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      // Maintain immersive mode when exiting fullscreen to portrait
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      Navigator.pop(context);
    }
  }

  void _onTap() {
    if (_locked) {
      _flashLockMessage();
      return;
    }
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_vpc?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  void _keepControlsVisible() {
    _hideTimer?.cancel();
    if (mounted) setState(() => _showControls = true);
    _startHideTimer();
  }

  void _flashLockMessage() {
    setState(() => _showLockFlash = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showLockFlash = false);
    });
  }

  void _seekBy(int seconds) {
    final ctrl = _vpc;
    if (ctrl == null || (_info?.isLive ?? false)) return;

    final current = ctrl.value.position;
    final total = ctrl.value.duration;
    final newPosMs = (current.inMilliseconds + seconds * 1000).clamp(0, total.inMilliseconds);
    final newPos = Duration(milliseconds: newPosMs);
    ctrl.seekTo(newPos);

    _seekFeedbackTimer?.cancel();
    setState(() {
      _seekForward = seconds > 0;
      _seekSeconds = seconds.abs();
      _showSeekFeedback = true;
    });
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showSeekFeedback = false);
    });
    _keepControlsVisible();
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (_locked) return;
    final screenWidth = MediaQuery.of(context).size.width;
    _gestureIsLeft = details.globalPosition.dx < screenWidth / 2;
    _gestureStartY = details.globalPosition.dy;
    _gestureStartVal = _gestureIsLeft ? _brightness : _volume;
    _gestureType = _gestureIsLeft ? _GestureType.brightness : _GestureType.volume;
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_locked || _gestureType == _GestureType.none) return;
    final screenHeight = MediaQuery.of(context).size.height;
    final delta = (_gestureStartY - details.globalPosition.dy) / screenHeight;
    final newVal = (_gestureStartVal + delta).clamp(0.0, 1.0);

    if (_gestureIsLeft) {
      try {
        ScreenBrightness().setScreenBrightness(newVal);
      } catch (_) {}
      setState(() {
        _brightness = newVal;
        _gestureType = _GestureType.brightness;
      });
    } else {
      try {
        VolumeController().setVolume(newVal);
      } catch (_) {}
      setState(() {
        _volume = newVal;
        _gestureType = _GestureType.volume;
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails _) {
    _gestureHideTimer?.cancel();
    _gestureHideTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _gestureType = _GestureType.none);
    });
  }

  void _showScrollableSheet({
    required String title,
    required List<Widget> items,
  }) {
    _hideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF2A2A2A), height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: items,
                ),
              ),
            ),
            // Bottom spacing (Safe Area)
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    ).then((_) => _startHideTimer());
  }

  void _showSpeedSheet() {
    const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    _showScrollableSheet(
      title: 'Playback Speed',
      items: speeds
          .map(
            (s) => ListTile(
              title: Text(
                s == 1.0 ? 'Normal (1x)' : '${s}x',
                style: TextStyle(
                  color: s == _speed ? Colors.red : Colors.white,
                  fontWeight: s == _speed ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: s == _speed
                  ? const Icon(Icons.check, color: Colors.red, size: 18)
                  : null,
              onTap: () {
                setState(() => _speed = s);
                _vpc?.setPlaybackSpeed(s);
                Navigator.pop(context);
              },
            ),
          )
          .toList(),
    );
  }

  void _showQualitySheet() {
    if (_info == null) return;
    _showScrollableSheet(
      title: 'Video Quality',
      items: _info!.qualities
          .map(
            (q) => ListTile(
              title: Text(
                q.label,
                style: TextStyle(
                  color: q.label == _quality?.label ? Colors.red : Colors.white,
                  fontWeight: q.label == _quality?.label
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              trailing: q.label == _quality?.label
                  ? const Icon(Icons.check, color: Colors.red, size: 18)
                  : null,
              onTap: () {
                Navigator.pop(context);
                _loadVideo(quality: q);
              },
            ),
          )
          .toList(),
    );
  }

  void _showFitSheet() {
    _showScrollableSheet(
      title: 'Video Size',
      items: [
        ListTile(
          leading: Icon(
            Icons.fit_screen,
            color: _fit == VideoFit.contain ? Colors.red : Colors.white54,
          ),
          title: Text(
            'Fit to screen',
            style: TextStyle(
              color: _fit == VideoFit.contain ? Colors.red : Colors.white,
            ),
          ),
          subtitle: const Text(
            'Black bars visible, full video shown',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          trailing: _fit == VideoFit.contain
              ? const Icon(Icons.check, color: Colors.red, size: 18)
              : null,
          onTap: () {
            setState(() => _fit = VideoFit.contain);
            Navigator.pop(context);
          },
        ),
        ListTile(
          leading: Icon(
            Icons.crop_free,
            color: _fit == VideoFit.cover ? Colors.red : Colors.white54,
          ),
          title: Text(
            'Fill screen (crop)',
            style: TextStyle(
              color: _fit == VideoFit.cover ? Colors.red : Colors.white,
            ),
          ),
          subtitle: const Text(
            'Fills screen, edges may be cropped',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          trailing: _fit == VideoFit.cover
              ? const Icon(Icons.check, color: Colors.red, size: 18)
              : null,
          onTap: () {
            setState(() => _fit = VideoFit.cover);
            Navigator.pop(context);
          },
        ),
        ListTile(
          leading: Icon(
            Icons.aspect_ratio,
            color: _fit == VideoFit.fill ? Colors.red : Colors.white54,
          ),
          title: Text(
            'Stretch',
            style: TextStyle(
              color: _fit == VideoFit.fill ? Colors.red : Colors.white,
            ),
          ),
          subtitle: const Text(
            'Fills entirely, may distort aspect ratio',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          trailing: _fit == VideoFit.fill
              ? const Icon(Icons.check, color: Colors.red, size: 18)
              : null,
          onTap: () {
            setState(() => _fit = VideoFit.fill);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget _sheetHandle() => Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  /// Builds the video rendering widget with proper Contain / Cover / Fill.
  /// Uses LayoutBuilder + Transform.scale + ClipRect so resizing actually works.
  Widget _buildVideoWidget() {
    final ctrl = _vpc!;
    final videoWidth = ctrl.value.size.width;
    final videoHeight = ctrl.value.size.height;

    // Guard against degenerate sizes
    if (videoWidth <= 0 || videoHeight <= 0) {
      return VideoPlayer(ctrl);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final boxW = constraints.maxWidth;
        final boxH = constraints.maxHeight;

        if (boxW <= 0 || boxH <= 0) return VideoPlayer(ctrl);

        final videoAspect = videoWidth / videoHeight;
        final boxAspect = boxW / boxH;

        double scaleX = 1.0;
        double scaleY = 1.0;

        switch (_fit) {
          case VideoFit.contain:
            // Scale down to fit inside box, maintain aspect ratio
            if (videoAspect > boxAspect) {
              // Video is wider → fit by width
              scaleX = 1.0;
              scaleY = boxAspect / videoAspect;
            } else {
              // Video is taller → fit by height
              scaleX = videoAspect / boxAspect;
              scaleY = 1.0;
            }
            break;
          case VideoFit.cover:
            // Scale up to fill box, crop edges, maintain aspect ratio
            if (videoAspect > boxAspect) {
              // Video is wider → fit by height, crop sides
              scaleX = boxAspect / videoAspect;
              scaleY = 1.0;
              // need to invert to fill:
              scaleX = 1.0 / scaleX;
              scaleY = 1.0 / scaleY;
            } else {
              scaleX = 1.0;
              scaleY = videoAspect / boxAspect;
              scaleX = 1.0 / scaleX;
              scaleY = 1.0 / scaleY;
            }
            break;
          case VideoFit.fill:
            // Stretch to completely fill the box (may distort)
            scaleX = boxW / (boxH * videoAspect);
            scaleY = 1.0;
            break;
        }

        return ClipRect(
          child: SizedBox.expand(
            child: FittedBox(
              fit: _fit == VideoFit.contain
                  ? BoxFit.contain
                  : _fit == VideoFit.cover
                      ? BoxFit.cover
                      : BoxFit.fill,
              child: SizedBox(
                width: videoWidth,
                height: videoHeight,
                child: VideoPlayer(ctrl),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _gestureHideTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _vpc?.dispose();
    VolumeController().removeListener();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onTap,
                onDoubleTapDown: (details) {
                  if (_locked) return;
                  final isRight = details.globalPosition.dx > MediaQuery.of(context).size.width / 2;
                  _seekBy(isRight ? 10 : -10);
                },
                onVerticalDragStart: _onVerticalDragStart,
                onVerticalDragUpdate: _onVerticalDragUpdate,
                onVerticalDragEnd: _onVerticalDragEnd,
                child: Container(
                  width: double.infinity,
                  height: _isFullscreen ? double.infinity : 220,
                  color: Colors.black,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_vpc != null && _vpc!.value.isInitialized)
                        Positioned.fill(
                          child: _buildVideoWidget(),
                        ),
                      if (_loading) const CircularProgressIndicator(color: Colors.red),
                      if (_error != null)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.white70, size: 42),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            TextButton(onPressed: () => _loadVideo(), child: const Text('RETRY', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      if (_gestureType == _GestureType.brightness) _buildBrightnessOverlay(),
                      if (_gestureType == _GestureType.volume) _buildVolumeOverlay(),
                      if (_showSeekFeedback) _buildSeekFeedback(),
                      if (_showLockFlash) _buildLockFlash(),
                      if (_showControls && !_loading && _error == null) _buildControlsOverlay(),
                    ],
                  ),
                ),
              ),
            ),
            if (!_isFullscreen) _buildDetailsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: const Color(0xFF0F0F0F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _info?.title ?? widget.title,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _info?.author ?? 'Loading details...',
            style: GoogleFonts.outfit(
              color: Colors.white60,
              fontSize: 14,
            ),
          ),
          if (_info?.isLive ?? false) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
              child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Colors.transparent, Colors.transparent, Color(0xCC000000)],
          stops: [0.0, 0.30, 0.70, 1.0],
        ),
      ),
      child: Column(
        children: [
          _buildTopBar(),
          const Spacer(),
          _buildCenterControls(),
          const Spacer(),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Row(
        children: [
          IconButton(onPressed: _onBack, icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
          if (_isFullscreen)
            Expanded(
              child: Text(
                _info?.title ?? widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          const Spacer(),
          if (_info?.isLive ?? false)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                child: const Text('● LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ),
          if (!_locked) ...[
            _buildControlBadge('${_speed}x', _showSpeedSheet),
            _buildControlBadge(_quality?.label ?? '--', _showQualitySheet),
            IconButton(onPressed: _showFitSheet, icon: const Icon(Icons.fit_screen_rounded, color: Colors.white, size: 20)),
          ],
          IconButton(
            onPressed: () => setState(() => _locked = !_locked),
            icon: Icon(_locked ? Icons.lock_rounded : Icons.lock_open_rounded, color: _locked ? Colors.red : Colors.white, size: 20),
          ),
          IconButton(
            onPressed: _toggleFullscreen,
            icon: Icon(_isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBadge(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildCenterControls() {
    if (_locked) return const SizedBox();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!(_info?.isLive ?? false))
          IconButton(onPressed: () => _seekBy(-10), icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 36)),
        const SizedBox(width: 30),
        GestureDetector(
          onTap: () {
            if (_vpc!.value.isPlaying) {
              _vpc!.pause();
            } else {
              _vpc!.play();
            }
            _keepControlsVisible();
          },
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle, border: Border.all(color: Colors.white54, width: 1.5)),
            child: Icon(_vpc!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 38),
          ),
        ),
        const SizedBox(width: 30),
        if (!(_info?.isLive ?? false))
          IconButton(onPressed: () => _seekBy(10), icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 36)),
      ],
    );
  }

  Widget _buildBottomBar() {
    final live = _info?.isLive ?? false;
    return Column(
      children: [
        if (!live && !_locked) _buildProgressBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(_volume == 0 ? Icons.volume_off : Icons.volume_up, color: Colors.white54, size: 18),
              if (!live)
                Text(
                  '${_fmt(_vpc!.value.position)} / ${_fmt(_vpc!.value.duration)}',
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final pos = _vpc!.value.position.inSeconds.toDouble();
    final dur = _vpc!.value.duration.inSeconds.toDouble();
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        trackHeight: 3,
        activeTrackColor: Colors.red,
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.red,
        overlayColor: Colors.red.withOpacity(0.2),
      ),
      child: Slider(
        value: pos.clamp(0.0, dur),
        min: 0.0,
        max: dur.clamp(1.0, double.infinity),
        onChanged: (v) {
          _vpc!.seekTo(Duration(seconds: v.toInt()));
          _keepControlsVisible();
        },
      ),
    );
  }

  Widget _buildBrightnessOverlay() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_brightness > 0.5 ? Icons.brightness_high : Icons.brightness_low, color: const Color(0xFFF0C040), size: 28),
            const SizedBox(height: 8),
            SizedBox(
              width: 90,
              child: LinearProgressIndicator(
                value: _brightness,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Color(0xFFF0C040)),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 6),
            Text('${(_brightness * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeOverlay() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: const Color(0xFF60C0F0), size: 28),
            const SizedBox(height: 8),
            SizedBox(
              width: 90,
              child: LinearProgressIndicator(
                value: _volume,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF60C0F0)),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 6),
            Text('${(_volume * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekFeedback() {
    return Align(
      alignment: _seekForward ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_seekForward ? Icons.forward_10_rounded : Icons.replay_10_rounded, color: Colors.white, size: 32),
              Text('${_seekSeconds}s', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockFlash() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text('Controls locked', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
