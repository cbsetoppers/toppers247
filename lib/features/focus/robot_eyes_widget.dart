import 'package:flutter/material.dart';
import 'focus_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RobotEyesWidget
// Flutter port of RobotEyesView.swift + EyeAnimator.swift
// Draws pixel-art robot eyes using CustomPainter.
// Mood changes animate the eyelids/height.
// ─────────────────────────────────────────────────────────────────────────────

class RobotEyesWidget extends StatefulWidget {
  final FocusMood mood;
  final DistractionPhase phase;
  /// The app's selected primary colour — tints the eyes when focused/happy.
  final Color focusedColor;

  const RobotEyesWidget({
    super.key,
    required this.mood,
    required this.phase,
    this.focusedColor = const Color(0xFFFFD700), // default golden
  });

  @override
  State<RobotEyesWidget> createState() => _RobotEyesWidgetState();
}

class _RobotEyesWidgetState extends State<RobotEyesWidget>
    with TickerProviderStateMixin {
  // Eye height animation (0.0 = closed, 1.0 = fully open)
  late AnimationController _eyeHeightCtrl;
  late Animation<double> _eyeHeightAnim;

  // Eyelid animation
  late AnimationController _eyelidCtrl;
  late Animation<double> _eyelidAnim;

  // Blink timer
  late AnimationController _blinkCtrl;

  // Flicker for idle
  late AnimationController _flickerCtrl;
  late Animation<double> _flickerX;
  late Animation<double> _flickerY;

  // Red eye tint for critical phase
  late AnimationController _redCtrl;
  late Animation<double> _redAnim;

  // Shake for critical DISTRACTED text (passed down via parent)
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  // Boot sequence
  bool _isBooting = true;
  final List<String> _braille = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
  int _brailleIndex = 0;
  late AnimationController _bootCtrl;

  @override
  void initState() {
    super.initState();

    _eyeHeightCtrl = AnimationController(vsync: this, duration: 300.ms);
    _eyeHeightAnim = CurvedAnimation(parent: _eyeHeightCtrl, curve: Curves.easeOut);
    _eyeHeightCtrl.value = 1.0;

    _eyelidCtrl = AnimationController(vsync: this, duration: 300.ms);
    _eyelidAnim = CurvedAnimation(parent: _eyelidCtrl, curve: Curves.easeOut);

    _blinkCtrl = AnimationController(vsync: this, duration: 120.ms);
    _scheduleNextBlink();

    _flickerCtrl = AnimationController(vsync: this, duration: 2000.ms)
      ..repeat(reverse: true);
    _flickerX = Tween<double>(begin: -1.5, end: 1.5).animate(
        CurvedAnimation(parent: _flickerCtrl, curve: Curves.easeInOut));
    _flickerY = Tween<double>(begin: -0.5, end: 0.5).animate(
        CurvedAnimation(parent: _flickerCtrl, curve: Curves.easeInOut));

    _redCtrl = AnimationController(vsync: this, duration: 400.ms);
    _redAnim = CurvedAnimation(parent: _redCtrl, curve: Curves.easeInOut);

    _shakeCtrl = AnimationController(vsync: this, duration: 80.ms);
    _shakeAnim = Tween<double>(begin: -4, end: 4).animate(_shakeCtrl);

    // Boot animation
    _bootCtrl = AnimationController(vsync: this, duration: 100.ms)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() => _brailleIndex = (_brailleIndex + 1) % _braille.length);
          _bootCtrl.reset();
          if (_isBooting) _bootCtrl.forward();
        }
      });
    _bootCtrl.forward();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _isBooting = false);
    });
  }

  void _scheduleNextBlink() {
    Future.delayed(
      Duration(milliseconds: 2500 + (DateTime.now().millisecondsSinceEpoch % 2000)),
      () {
        if (!mounted) return;
        _blinkCtrl.forward().then((_) => _blinkCtrl.reverse().then((_) {
              if (mounted) _scheduleNextBlink();
            }));
      },
    );
  }

  @override
  void didUpdateWidget(covariant RobotEyesWidget old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) _applyMood(widget.mood);
    if (old.phase != widget.phase) {
      if (widget.phase == DistractionPhase.critical) {
        _redCtrl.forward();
        _startShaking();
      } else {
        _redCtrl.reverse();
        _shakeCtrl.stop();
        _shakeCtrl.value = 0;
      }
    }
  }

  void _startShaking() {
    _shakeCtrl.repeat(reverse: true);
  }

  void _applyMood(FocusMood mood) {
    switch (mood) {
      case FocusMood.angry:
        _eyelidCtrl.animateTo(1.0);
        _eyeHeightCtrl.animateTo(0.7);
      case FocusMood.tired:
        _eyelidCtrl.animateTo(0.55, curve: Curves.easeOut);
        _eyeHeightCtrl.animateTo(0.6);
      case FocusMood.happy:
        _eyelidCtrl.animateTo(0.3);
        _eyeHeightCtrl.animateTo(0.85);
      case FocusMood.curious:
        _eyelidCtrl.animateTo(0.0);
        _eyeHeightCtrl.animateTo(1.2, curve: Curves.elasticOut);
      case FocusMood.normal:
        _eyelidCtrl.animateTo(0.0);
        _eyeHeightCtrl.animateTo(1.0);
    }
  }

  @override
  void dispose() {
    _eyeHeightCtrl.dispose();
    _eyelidCtrl.dispose();
    _blinkCtrl.dispose();
    _flickerCtrl.dispose();
    _redCtrl.dispose();
    _shakeCtrl.dispose();
    _bootCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _eyeHeightAnim, _eyelidAnim, _blinkCtrl,
        _flickerX, _flickerY, _redAnim, _shakeAnim,
      ]),
      builder: (context, _) {
        return Transform.translate(
          offset: widget.phase == DistractionPhase.critical
              ? Offset(_shakeAnim.value, 0)
              : Offset.zero,
          child: CustomPaint(
            painter: _RobotEyesPainter(
              isBooting: _isBooting,
              brailleChar: _braille[_brailleIndex],
              eyeHeightFactor: (_eyeHeightAnim.value *
                  (1.0 - _blinkCtrl.value)).clamp(0, 1.5),
              eyelidFactor: _eyelidAnim.value,
              mood: widget.mood,
              flickerX: _flickerX.value,
              flickerY: _flickerY.value,
              redFactor: _redAnim.value,
              focusedColor: widget.focusedColor,
            ),
          ),
        );
      },
    );
  }
}

class _RobotEyesPainter extends CustomPainter {
  final bool isBooting;
  final String brailleChar;
  final double eyeHeightFactor;
  final double eyelidFactor;
  final FocusMood mood;
  final double flickerX;
  final double flickerY;
  final double redFactor;
  final Color focusedColor;

  const _RobotEyesPainter({
    required this.isBooting,
    required this.brailleChar,
    required this.eyeHeightFactor,
    required this.eyelidFactor,
    required this.mood,
    required this.flickerX,
    required this.flickerY,
    required this.redFactor,
    required this.focusedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.black;
    canvas.drawRect(Offset.zero & size, bg);

    // Scanlines
    final scanPaint = Paint()..color = Colors.black.withOpacity(0.12);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), scanPaint);
    }

    if (isBooting) {
      // Braille boot spinner in centre
      final tp = TextPainter(
        text: TextSpan(
          text: brailleChar,
          style: TextStyle(
            fontSize: size.height * 0.45,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
      return;
    }

    // Eye dimensions
    final eyeW = size.width * 0.30;
    final eyeSpacing = size.width * 0.08;
    final totalW = eyeW * 2 + eyeSpacing;
    final startX = (size.width - totalW) / 2 + flickerX;
    final maxEyeH = size.height * 0.65;
    final eyeH = (maxEyeH * eyeHeightFactor).clamp(2.0, maxEyeH * 1.3);
    final startY = (size.height - eyeH) / 2 + flickerY - (size.height * 0.08);
    final radius = eyeW * 0.22;

    // Eye colour:
    //   Normal / happy / focused → white lerped toward the selected primary colour
    //   Critical                 → white lerped toward red (override)
    //   Angry / tired / curious  → white lerped toward orange
    final baseEyeColor = switch (mood) {
      FocusMood.normal  => Color.lerp(Colors.white, focusedColor, 0.55)!,
      FocusMood.happy   => Color.lerp(Colors.white, focusedColor, 0.80)!,
      FocusMood.curious => Color.lerp(Colors.white, Colors.amber,  0.65)!,
      FocusMood.angry   => Color.lerp(Colors.white, Colors.orange, 0.75)!,
      FocusMood.tired   => Color.lerp(Colors.white, Colors.grey,   0.55)!,
    };
    // Overlay red on top when in critical phase
    final eyeColor = Color.lerp(baseEyeColor, const Color(0xFFFF3322), redFactor)!;
    final eyePaint = Paint()..color = eyeColor;
    final blackPaint = Paint()..color = Colors.black;

    final leftRect  = Rect.fromLTWH(startX, startY, eyeW, eyeH);
    final rightRect = Rect.fromLTWH(startX + eyeW + eyeSpacing, startY, eyeW, eyeH);

    // Draw eyes
    canvas.drawRRect(RRect.fromRectAndRadius(leftRect, Radius.circular(radius)), eyePaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rightRect, Radius.circular(radius)), eyePaint);

    // Eyelid overlays
    final eyelidH = eyeH * eyelidFactor * 0.65;

    if (eyelidH > 1) {
      if (mood == FocusMood.tired) {
        // Tired: droop outward (triangle from outer corner)
        final ltPath = Path()
          ..moveTo(leftRect.left, leftRect.top - 1)
          ..lineTo(leftRect.right, leftRect.top - 1)
          ..lineTo(leftRect.left, leftRect.top + eyelidH - 1)
          ..close();
        canvas.drawPath(ltPath, blackPaint);

        final rtPath = Path()
          ..moveTo(rightRect.left, rightRect.top - 1)
          ..lineTo(rightRect.right, rightRect.top - 1)
          ..lineTo(rightRect.right, rightRect.top + eyelidH - 1)
          ..close();
        canvas.drawPath(rtPath, blackPaint);
      } else if (mood == FocusMood.angry || mood == FocusMood.curious) {
        // Angry: furrowed inward (triangle from inner corner)
        final laPath = Path()
          ..moveTo(leftRect.left, leftRect.top - 1)
          ..lineTo(leftRect.right, leftRect.top - 1)
          ..lineTo(leftRect.right, leftRect.top + eyelidH - 1)
          ..close();
        canvas.drawPath(laPath, blackPaint);

        final raPath = Path()
          ..moveTo(rightRect.left, rightRect.top - 1)
          ..lineTo(rightRect.right, rightRect.top - 1)
          ..lineTo(rightRect.left, rightRect.top + eyelidH - 1)
          ..close();
        canvas.drawPath(raPath, blackPaint);
      } else if (mood == FocusMood.happy) {
        // Happy: rounded caps covering bottom portion
        final happyOffset = eyeH * eyelidFactor * 0.5;
        final lhRect = Rect.fromLTWH(
          leftRect.left - 1,
          leftRect.bottom - happyOffset + 1,
          leftRect.width + 2,
          happyOffset + 4,
        );
        canvas.drawRRect(
            RRect.fromRectAndRadius(lhRect, Radius.circular(radius)),
            blackPaint);

        final rhRect = Rect.fromLTWH(
          rightRect.left - 1,
          rightRect.bottom - happyOffset + 1,
          rightRect.width + 2,
          happyOffset + 4,
        );
        canvas.drawRRect(
            RRect.fromRectAndRadius(rhRect, Radius.circular(radius)),
            blackPaint);
      }
    }

    // --- DRAW MOUTH ---
    final mouthY = startY + eyeH + (size.height * 0.1);
    final mouthW = eyeSpacing + eyeW * 0.45;
    final mouthX = (size.width - mouthW) / 2 + flickerX;

    final mouthPaint = Paint()
      ..color = eyeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.height * 0.04).clamp(1.5, 3.5)
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path();

    switch (mood) {
      case FocusMood.happy:
        mouthPath.moveTo(mouthX, mouthY);
        mouthPath.quadraticBezierTo(
            mouthX + mouthW / 2, mouthY + (size.height * 0.12),
            mouthX + mouthW, mouthY);
        break;
      case FocusMood.angry:
        mouthPath.moveTo(mouthX, mouthY + (size.height * 0.05));
        mouthPath.quadraticBezierTo(
            mouthX + mouthW / 2, mouthY - (size.height * 0.05),
            mouthX + mouthW, mouthY + (size.height * 0.05));
        break;
      case FocusMood.curious:
        mouthPath.moveTo(mouthX, mouthY);
        mouthPath.lineTo(mouthX + mouthW * 0.33, mouthY + (size.height * 0.03));
        mouthPath.lineTo(mouthX + mouthW * 0.66, mouthY - (size.height * 0.03));
        mouthPath.lineTo(mouthX + mouthW, mouthY + (size.height * 0.03));
        break;
      case FocusMood.tired:
        final shortW = mouthW * 0.35;
        final shortX = (size.width - shortW) / 2 + flickerX;
        mouthPath.moveTo(shortX, mouthY);
        mouthPath.lineTo(shortX + shortW, mouthY);
        break;
      default:
        mouthPath.moveTo(mouthX, mouthY);
        mouthPath.lineTo(mouthX + mouthW, mouthY);
        break;
    }
    canvas.drawPath(mouthPath, mouthPaint);
  }

  @override
  bool shouldRepaint(covariant _RobotEyesPainter old) =>
      old.eyeHeightFactor != eyeHeightFactor ||
      old.eyelidFactor    != eyelidFactor ||
      old.mood            != mood ||
      old.flickerX        != flickerX ||
      old.flickerY        != flickerY ||
      old.redFactor       != redFactor ||
      old.focusedColor    != focusedColor ||
      old.isBooting       != isBooting ||
      old.brailleChar     != brailleChar;
}

// Helper extension
extension on int {
  Duration get ms => Duration(milliseconds: this);
}
