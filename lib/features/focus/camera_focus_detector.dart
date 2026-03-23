import 'dart:async';
import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CameraFocusDetector  (v2 — with smoothing buffer)
//
// Tolerance tuning:
//   • yawLimit   — how far left/right head can turn     (was 35°, now 50°)
//   • pitchLimit — how far up/down head can tilt         (new, 40°)
//   • rollLimit  — how far head can rotate sideways      (new, 35°)
//   • eyeMin     — minimum eye-openness probability      (was 0.25, now 0.15)
//   • asymmetryMax — max L/R eye openness asymmetry      (was 0.5, now 0.65)
//
// Smoothing:
//   • Requires _requiredConsecutive "not focused" frames before
//     switching to distracted, so a single tilted frame doesn't trigger.
//   • Focused → distracted: needs 4 consecutive unfocused frames (~400ms)
//   • Distracted → focused: immediate (1 frame is enough)
// ─────────────────────────────────────────────────────────────────────────────

class CameraFocusDetector extends ChangeNotifier {
  // ── Tolerance knobs ──────────────────────────────────────────────
  static const double _yawLimit       = 65.0; // degrees left/right (more radius)
  static const double _pitchLimit     = 55.0; // degrees up/down
  static const double _rollLimit      = 45.0; // degrees tilt
  static const double _eyeMin         = 0.12; // eye openness threshold
  static const double _asymmetryMax   = 0.70; // L/R eye asymmetry limit
  static const int    _requiredConsecutive = 8; // ~1s of unfocused frames to confirm distraction

  // ── State ────────────────────────────────────────────────────────
  CameraController?   _controller;
  CameraDescription?  _frontCamera;

  bool    _isFocused       = false;
  bool    _isInitialized   = false;
  bool    _isProcessing    = false;
  String? _error;
  int     _unfocusedStreak = 0; // consecutive unfocused frames

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,  // eye openness probability
      enableLandmarks: false,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.08,
    ),
  );

  // ── Public getters ───────────────────────────────────────────────
  bool    get isFocused      => _isFocused;
  bool    get isInitialized  => _isInitialized;
  String? get error          => _error;
  CameraController? get controller => _controller;

  // ── Lifecycle ────────────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      final cameras = await availableCameras();
      _frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        _frontCamera!,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _controller!.initialize();
      _isInitialized = true;
      _error = null;
      notifyListeners();

      await _controller!.startImageStream(_processFrame);
    } catch (e) {
      _error = e.toString();
      _isInitialized = false;
      notifyListeners();
      debugPrint('CameraFocusDetector init error: $e');
    }
  }

  // ── Frame processing ─────────────────────────────────────────────

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final inputImage = _buildInputImage(image);
      if (inputImage == null) { _isProcessing = false; return; }

      final faces   = await _faceDetector.processImage(inputImage);
      final rawFocus = _evaluateFocus(faces);

      // ── Smoothing buffer ──────────────────────────────────────────
      // Focused → unfocused: only commit after N consecutive unfocused frames
      // Unfocused → focused: commit immediately (1 frame is enough)
      if (rawFocus) {
        _unfocusedStreak = 0;
        if (!_isFocused) {
          _isFocused = true;
          notifyListeners();
        }
      } else {
        _unfocusedStreak++;
        if (_unfocusedStreak >= _requiredConsecutive && _isFocused) {
          _isFocused = false;
          notifyListeners();
        }
      }
    } catch (_) {
      // Silently swallow frame errors
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _buildInputImage(CameraImage image) {
    if (_controller == null || _frontCamera == null) return null;

    final rotation = InputImageRotationValue.fromRawValue(
        _frontCamera!.sensorOrientation) ??
        InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  // ── Focus evaluation (single frame) ────────────────────────────
  // Returns true if this single frame looks "focused".
  // Smoothing is handled in _processFrame above.

  bool _evaluateFocus(List<Face> faces) {
    if (faces.isEmpty) return false;
    final face = faces.first;

    // Eye openness — more lenient threshold (0.15 vs old 0.25)
    final leftOpen  = face.leftEyeOpenProbability  ?? 0.0;
    final rightOpen = face.rightEyeOpenProbability ?? 0.0;
    if (leftOpen < _eyeMin || rightOpen < _eyeMin) return false;

    // Symmetry — students often close one eye slightly when thinking
    final avg = (leftOpen + rightOpen) / 2;
    if (avg <= 0) return false;
    final asymmetry = (leftOpen - rightOpen).abs() / avg;
    if (asymmetry > _asymmetryMax) return false;

    // Head yaw (left/right turn) — increased from 35° to 50°
    final yaw = face.headEulerAngleY ?? 0.0;
    if (yaw.abs() > _yawLimit) return false;

    // Head pitch (looking up/down) — new check, 40°
    final pitch = face.headEulerAngleX ?? 0.0;
    if (pitch.abs() > _pitchLimit) return false;

    // Head roll (tilting sideways) — new check, 35°
    final roll = face.headEulerAngleZ ?? 0.0;
    if (roll.abs() > _rollLimit) return false;

    return true;
  }

  // ── Cleanup ──────────────────────────────────────────────────────

  Future<void> stop() async {
    try {
      await _controller?.stopImageStream();
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
    _isInitialized = false;
    _isFocused = false;
    _unfocusedStreak = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _faceDetector.close();
    super.dispose();
  }
}
