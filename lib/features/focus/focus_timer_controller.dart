import 'dart:async';
import 'package:flutter/foundation.dart';
import 'focus_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FocusTimerController
// Port of TimerState.swift + FocusMoodController.swift combined.
// ─────────────────────────────────────────────────────────────────────────────

class FocusTimerController extends ChangeNotifier {
  // ── Timer state ────────────────────────────────────────────
  TimerMode mode = TimerMode.idle;
  int totalSeconds = 0;
  int elapsedSeconds = 0; // counts up in free mode, used for countdowns too
  bool frozen = false;

  // ── Mood & distraction ──────────────────────────────────────
  FocusMood mood = FocusMood.normal;
  DistractionPhase phase = DistractionPhase.none;
  bool isFocused = false;

  // ── Internals ───────────────────────────────────────────────
  Timer? _ticker;
  DateTime? _distractedSince;
  DateTime? _focusedSince;
  DateTime? _tiredUntil;
  bool _didResetThisPeriod = false;
  bool _wasDistracted = false;

  // Thresholds (seconds) — same as Swift original
  static const _searchDuration = 3;
  static const _angryDuration  = 6;
  static const _criticalDuration = 9;
  static const _tiredDuration  = 3;
  static const _refocusThreshold = 2;

  // Callbacks
  VoidCallback? onComplete;
  VoidCallback? onTimerReset;
  VoidCallback? onUserReturned;

  // ── Computed helpers ────────────────────────────────────────
  bool get isRunning => mode == TimerMode.running;
  bool get isCountdown => totalSeconds > 0;

  int get remainingSeconds =>
      isCountdown ? (totalSeconds - elapsedSeconds).clamp(0, totalSeconds) : 0;

  double get progress =>
      totalSeconds > 0 ? elapsedSeconds / totalSeconds : 0;

  /// What to display in the timer area
  String get displayTime {
    if (phase == DistractionPhase.angry || phase == DistractionPhase.critical) {
      return 'DISTRACTED';
    }
    final secs = isCountdown ? remainingSeconds : elapsedSeconds;
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get showRedEyes => phase == DistractionPhase.critical;

  // ── Timer control ───────────────────────────────────────────

  void start({required int minutes}) {
    totalSeconds = minutes * 60;
    elapsedSeconds = 0;
    mode = TimerMode.running;
    frozen = false;
    phase = DistractionPhase.none;
    mood = FocusMood.normal;
    _distractedSince = null;
    _focusedSince = null;
    _tiredUntil = null;
    _didResetThisPeriod = false;
    _wasDistracted = false;
    _startTicking();
    notifyListeners();
  }

  void startFree() {
    totalSeconds = 0;
    elapsedSeconds = 0;
    mode = TimerMode.running;
    frozen = false;
    phase = DistractionPhase.none;
    mood = FocusMood.normal;
    _startTicking();
    notifyListeners();
  }

  void stop() {
    _ticker?.cancel();
    mode = TimerMode.idle;
    elapsedSeconds = 0;
    totalSeconds = 0;
    frozen = false;
    phase = DistractionPhase.none;
    mood = FocusMood.normal;
    notifyListeners();
  }

  void _resetTimer() {
    if (totalSeconds > 0) {
      elapsedSeconds = 0;
    }
    frozen = false;
    phase = DistractionPhase.none;
    onTimerReset?.call();
    notifyListeners();
  }

  void _complete() {
    _ticker?.cancel();
    mode = TimerMode.completed;
    mood = FocusMood.happy;
    frozen = false;
    phase = DistractionPhase.none;
    onComplete?.call();
    notifyListeners();

    // Auto-reset to idle after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mode == TimerMode.completed) {
        mood = FocusMood.normal;
        mode = TimerMode.idle;
        notifyListeners();
      }
    });
  }

  void _startTicking() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (frozen) return;
    if (isCountdown) {
      if (elapsedSeconds < totalSeconds) {
        elapsedSeconds++;
        if (elapsedSeconds >= totalSeconds) {
          _complete();
          return;
        }
      }
    } else {
      elapsedSeconds++;
    }
    notifyListeners();
  }

  // ── Focus detection input ───────────────────────────────────
  // Called by the camera/ML kit detector every frame.

  void updateFocus(bool focused) {
    isFocused = focused;
    final now = DateTime.now();

    if (focused) {
      _distractedSince = null;
      _focusedSince ??= now;

      // Post-reset tired period
      if (_tiredUntil != null && now.isBefore(_tiredUntil!)) {
        mood = FocusMood.tired;
        phase = DistractionPhase.reset;
        if (frozen) { frozen = false; }
        notifyListeners();
        return;
      }
      if (_tiredUntil != null) _tiredUntil = null;

      // Coming back from distraction
      if (_wasDistracted) {
        _wasDistracted = false;
        _didResetThisPeriod = false;
        phase = DistractionPhase.none;
        mood = FocusMood.happy;
        frozen = false;
        onUserReturned?.call();
        notifyListeners();
        return;
      }

      final focusedFor = now.difference(_focusedSince!).inSeconds;
      phase = DistractionPhase.none;
      mood = focusedFor >= _refocusThreshold ? FocusMood.normal : FocusMood.happy;
      frozen = false;
    } else {
      _focusedSince = null;
      _wasDistracted = true;
      _distractedSince ??= now;

      // Post-reset tired period
      if (_tiredUntil != null && now.isBefore(_tiredUntil!)) {
        mood = FocusMood.tired;
        phase = DistractionPhase.reset;
        notifyListeners();
        return;
      }
      if (_tiredUntil != null) {
        _tiredUntil = null;
        mood = FocusMood.curious;
        phase = DistractionPhase.none;
        notifyListeners();
        return;
      }

      if (!isRunning) {
        mood = FocusMood.curious;
        phase = DistractionPhase.none;
        notifyListeners();
        return;
      }

      final duration = now.difference(_distractedSince!).inSeconds;

      if (duration < _searchDuration) {
        mood = FocusMood.curious;
        phase = DistractionPhase.searching;
        frozen = true; // freeze timer while looking away
      } else if (duration < _angryDuration) {
        mood = FocusMood.angry;
        phase = DistractionPhase.angry;
        frozen = true;
      } else if (duration < _criticalDuration) {
        mood = FocusMood.angry;
        phase = DistractionPhase.critical;
        frozen = true;
      } else {
        if (!_didResetThisPeriod) {
          _didResetThisPeriod = true;
          _tiredUntil = now.add(const Duration(seconds: _tiredDuration));
          mood = FocusMood.tired;
          phase = DistractionPhase.reset;
          frozen = false;
          _resetTimer();
          return;
        } else {
          mood = FocusMood.curious;
          phase = DistractionPhase.none;
          frozen = false;
        }
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
