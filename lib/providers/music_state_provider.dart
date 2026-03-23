import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MusicMode { none, local, youtube, youtubeWebView }

class MusicState {
  final MusicMode mode;
  final bool isPlaying;
  final String title;
  final String? thumb;
  final String? webViewUrl;   // used by youtubeWebView mode
  final Duration position;
  final Duration duration;
  final String? error;

  MusicState({
    this.mode = MusicMode.none,
    this.isPlaying = false,
    this.title = '',
    this.thumb,
    this.webViewUrl,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
  });

  MusicState copyWith({
    MusicMode? mode,
    bool? isPlaying,
    String? title,
    String? thumb,
    String? webViewUrl,
    Duration? position,
    Duration? duration,
    String? error,
  }) {
    return MusicState(
      mode: mode ?? this.mode,
      isPlaying: isPlaying ?? this.isPlaying,
      title: title ?? this.title,
      thumb: thumb ?? this.thumb,
      webViewUrl: webViewUrl ?? this.webViewUrl,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      error: error ?? this.error,
    );
  }
}

class MusicNotifier extends Notifier<MusicState> {
  final _player = AudioPlayer();
  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;

  @override
  MusicState build() {
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      state = state.copyWith(isPlaying: s == PlayerState.playing);
    });
    _posSub = _player.onPositionChanged.listen((p) {
      state = state.copyWith(position: p);
    });
    _durSub = _player.onDurationChanged.listen((d) {
      state = state.copyWith(duration: d);
    });

    ref.onDispose(() {
      _stateSub?.cancel();
      _posSub?.cancel();
      _durSub?.cancel();
      _player.dispose();
    });

    return MusicState();
  }

  Future<void> playLocal(String path, String name) async {
    await _player.stop();
    await _player.play(DeviceFileSource(path));
    state = state.copyWith(
      mode: MusicMode.local,
      title: name,
      thumb: null,
      webViewUrl: null,
      error: null,
    );
  }

  /// Play YouTube audio via direct stream URL (legacy — may fail due to YT bot protection).
  Future<void> playYouTube(String url, String title, String? thumb) async {
    await _player.stop();
    await _player.play(UrlSource(url));
    state = state.copyWith(
      mode: MusicMode.youtube,
      title: title,
      thumb: thumb,
      webViewUrl: null,
      error: null,
    );
  }

  /// Open YouTube / YouTube Music in a WebView embedded inside the music tool.
  void setWebViewMode(String url, String title) {
    _player.stop(); // stop any audio player
    state = state.copyWith(
      mode: MusicMode.youtubeWebView,
      title: title,
      thumb: null,
      webViewUrl: url,
      isPlaying: true,   // assume playing (WebView handles its own state)
      error: null,
    );
  }

  void clearWebViewMode() {
    state = MusicState(); // reset to none
  }

  Future<void> pause() async => await _player.pause();
  Future<void> resume() async => await _player.resume();
  Future<void> stop() async {
    await _player.stop();
    state = MusicState(mode: MusicMode.none, isPlaying: false);
  }

  Future<void> seek(Duration pos) async => await _player.seek(pos);
}

final musicStateProvider = NotifierProvider<MusicNotifier, MusicState>(MusicNotifier.new);
