import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'robot_face.dart';

/// Layered botAi avatar.
///
/// The static robot helmet/circuit artwork is supplied by
/// assets/images/botai_robot_shell.png. This widget draws only the animated
/// eyes, nose and mouth on top of its blank visor, so the helmet stays fixed
/// while the face changes expression.
class BotAiRobotAvatar extends StatefulWidget {
  const BotAiRobotAvatar({
    super.key,
    required this.state,
    required this.emotion,
    this.volume = 0,
    this.size = 360,
    this.color = const Color(0xFF00F0FF),
  });

  final FaceState state;
  final FaceEmotion emotion;

  /// 0.0 to 1.0 audio level. While speaking, this drives mouth opening.
  /// Connect a real playback RMS/amplitude value here when the audio engine
  /// exposes one. The current voice screen can pass its existing visualizer
  /// level as a smooth fallback.
  final double volume;
  final double size;
  final Color color;

  @override
  State<BotAiRobotAvatar> createState() => _BotAiRobotAvatarState();
}

class _BotAiRobotAvatarState extends State<BotAiRobotAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _ambient;
  late final AnimationController _transition;
  late FaceEmotion _previousEmotion;
  late FaceState _previousState;

  @override
  void initState() {
    super.initState();
    _previousEmotion = widget.emotion;
    _previousState = widget.state;
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
    _transition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant BotAiRobotAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emotion != widget.emotion ||
        oldWidget.state != widget.state) {
      _previousEmotion = oldWidget.emotion;
      _previousState = oldWidget.state;
      _transition.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ambient.dispose();
    _transition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size.clamp(180.0, 560.0).toDouble();
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/botai_robot_shell.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder:
                  (context, error, stackTrace) => const ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: Icon(
                        Icons.smart_toy,
                        color: Color(0xFF00F0FF),
                        size: 72,
                      ),
                    ),
                  ),
            ),
            IgnorePointer(
              child: AnimatedBuilder(
                animation: Listenable.merge([_ambient, _transition]),
                builder: (context, _) {
                  final from = _BotAiFacePose.fromState(
                    _previousState,
                    _previousEmotion,
                  );
                  final to = _BotAiFacePose.fromState(
                    widget.state,
                    widget.emotion,
                  );
                  final pose = _BotAiFacePose.lerp(
                    from,
                    to,
                    Curves.easeInOutCubic.transform(_transition.value),
                  );
                  return CustomPaint(
                    painter: _BotAiFacePainter(
                      pose: pose,
                      time: _ambient.value * 4.2,
                      state: widget.state,
                      volume: widget.volume.clamp(0.0, 1.0).toDouble(),
                      color: widget.color,
                    ),
                    size: Size.square(size),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotAiFacePose {
  const _BotAiFacePose({
    this.eyeScaleX = 1,
    this.eyeScaleY = 1,
    this.eyeArch = 0,
    this.eyeSlant = 0,
    this.gazeX = 0,
    this.gazeY = 0,
    this.leftEyeScale = 1,
    this.rightEyeScale = 1,
    this.wink = 0,
    this.mouthWidth = 1,
    this.mouthCurve = 0.2,
    this.mouthOpen = 0,
    this.mouthRoundness = 0,
    this.noseScale = 1,
  });

  final double eyeScaleX;
  final double eyeScaleY;
  final double eyeArch;
  final double eyeSlant;
  final double gazeX;
  final double gazeY;
  final double leftEyeScale;
  final double rightEyeScale;
  final double wink;
  final double mouthWidth;
  final double mouthCurve;
  final double mouthOpen;
  final double mouthRoundness;
  final double noseScale;

  static _BotAiFacePose fromState(FaceState state, FaceEmotion emotion) {
    var p = const _BotAiFacePose();
    switch (emotion) {
      case FaceEmotion.happy:
        p = const _BotAiFacePose(
          eyeArch: 1,
          mouthCurve: 0.95,
          mouthOpen: 0.24,
          mouthWidth: 1.12,
          noseScale: 1.08,
        );
        break;
      case FaceEmotion.laughing:
        p = const _BotAiFacePose(
          eyeArch: 1,
          eyeScaleX: 1.08,
          mouthCurve: 1,
          mouthOpen: 0.62,
          mouthWidth: 1.2,
          noseScale: 1.12,
        );
        break;
      case FaceEmotion.sad:
        p = const _BotAiFacePose(
          eyeScaleY: 0.66,
          eyeSlant: -0.18,
          gazeY: 0.34,
          mouthCurve: -0.9,
          mouthWidth: 0.86,
        );
        break;
      case FaceEmotion.angry:
        p = const _BotAiFacePose(
          eyeScaleY: 0.66,
          eyeSlant: 0.42,
          mouthCurve: -0.58,
          mouthWidth: 0.9,
        );
        break;
      case FaceEmotion.surprised:
        p = const _BotAiFacePose(
          eyeScaleX: 1.22,
          eyeScaleY: 1.25,
          mouthRoundness: 1,
          mouthOpen: 0.85,
          mouthWidth: 0.7,
          noseScale: 1.28,
        );
        break;
      case FaceEmotion.loving:
        p = const _BotAiFacePose(
          eyeArch: 0.65,
          mouthCurve: 0.72,
          mouthOpen: 0.12,
          noseScale: 1.1,
        );
        break;
      case FaceEmotion.sleepy:
        p = const _BotAiFacePose(
          eyeScaleY: 0.28,
          gazeY: 0.16,
          mouthCurve: 0.05,
          mouthWidth: 0.72,
        );
        break;
      case FaceEmotion.confused:
        p = const _BotAiFacePose(
          leftEyeScale: 1.12,
          rightEyeScale: 0.76,
          eyeSlant: -0.12,
          gazeX: 0.24,
          mouthCurve: -0.12,
          mouthWidth: 0.78,
        );
        break;
      case FaceEmotion.winking:
        p = const _BotAiFacePose(
          wink: 1,
          eyeArch: 0.3,
          mouthCurve: 0.72,
          mouthWidth: 0.95,
        );
        break;
      case FaceEmotion.cool:
        p = const _BotAiFacePose(
          eyeScaleY: 0.48,
          eyeScaleX: 1.12,
          mouthCurve: 0.28,
          mouthWidth: 0.9,
        );
        break;
      case FaceEmotion.thinking:
        p = const _BotAiFacePose(
          gazeX: 0.45,
          gazeY: -0.48,
          eyeSlant: -0.06,
          mouthCurve: -0.12,
          mouthWidth: 0.78,
        );
        break;
      case FaceEmotion.neutral:
        break;
    }

    // Activity state has priority over the idle pose, without erasing emotion.
    switch (state) {
      case FaceState.listening:
        p = _BotAiFacePose(
          eyeScaleX: p.eyeScaleX * 1.06,
          eyeScaleY: p.eyeScaleY * 1.06,
          eyeArch: p.eyeArch,
          eyeSlant: p.eyeSlant,
          gazeX: p.gazeX,
          gazeY: p.gazeY,
          leftEyeScale: p.leftEyeScale,
          rightEyeScale: p.rightEyeScale,
          wink: p.wink,
          mouthWidth: p.mouthWidth,
          mouthCurve: p.mouthCurve,
          mouthOpen: p.mouthOpen,
          mouthRoundness: p.mouthRoundness,
          noseScale: p.noseScale,
        );
        break;
      case FaceState.thinking:
        p = _BotAiFacePose(
          eyeScaleX: p.eyeScaleX,
          eyeScaleY: p.eyeScaleY,
          eyeArch: p.eyeArch,
          eyeSlant: p.eyeSlant,
          gazeX: p.gazeX == 0 ? 0.4 : p.gazeX,
          gazeY: p.gazeY == 0 ? -0.45 : p.gazeY,
          leftEyeScale: p.leftEyeScale,
          rightEyeScale: p.rightEyeScale,
          wink: p.wink,
          mouthWidth: p.mouthWidth,
          mouthCurve: p.mouthCurve,
          mouthOpen: p.mouthOpen,
          mouthRoundness: p.mouthRoundness,
          noseScale: p.noseScale,
        );
        break;
      case FaceState.error:
        p = const _BotAiFacePose(
          eyeScaleY: 0.7,
          eyeSlant: 0.3,
          mouthCurve: -0.65,
          mouthWidth: 0.9,
        );
        break;
      case FaceState.connecting:
      case FaceState.idle:
      case FaceState.speaking:
      case FaceState.standby:
      case FaceState.wakeDetected:
      case FaceState.executing:
        break;
    }
    return p;
  }

  static _BotAiFacePose lerp(_BotAiFacePose a, _BotAiFacePose b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    return _BotAiFacePose(
      eyeScaleX: l(a.eyeScaleX, b.eyeScaleX),
      eyeScaleY: l(a.eyeScaleY, b.eyeScaleY),
      eyeArch: l(a.eyeArch, b.eyeArch),
      eyeSlant: l(a.eyeSlant, b.eyeSlant),
      gazeX: l(a.gazeX, b.gazeX),
      gazeY: l(a.gazeY, b.gazeY),
      leftEyeScale: l(a.leftEyeScale, b.leftEyeScale),
      rightEyeScale: l(a.rightEyeScale, b.rightEyeScale),
      wink: l(a.wink, b.wink),
      mouthWidth: l(a.mouthWidth, b.mouthWidth),
      mouthCurve: l(a.mouthCurve, b.mouthCurve),
      mouthOpen: l(a.mouthOpen, b.mouthOpen),
      mouthRoundness: l(a.mouthRoundness, b.mouthRoundness),
      noseScale: l(a.noseScale, b.noseScale),
    );
  }
}

class _BotAiFacePainter extends CustomPainter {
  _BotAiFacePainter({
    required this.pose,
    required this.time,
    required this.state,
    required this.volume,
    required this.color,
  });

  static const double _design = 1254;
  final _BotAiFacePose pose;
  final double time;
  final FaceState state;
  final double volume;
  final Color color;

  final Paint _glow =
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
  final Paint _stroke =
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
  final Paint _fill = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.scale(size.width / _design, size.height / _design);

    final core = Color.lerp(color, Colors.white, 0.72) ?? Colors.white;
    final blink = _blinkAmount(time);
    final idleGazeX =
        state == FaceState.idle ? math.sin(time * 0.7) * 4.0 : 0.0;
    final idleGazeY =
        state == FaceState.idle ? math.cos(time * 0.5) * 2.5 : 0.0;

    _drawEye(
      canvas,
      center: Offset(
        462 + pose.gazeX * 30 + idleGazeX,
        605 + pose.gazeY * 18 + idleGazeY,
      ),
      scaleX: pose.eyeScaleX * pose.leftEyeScale,
      scaleY: pose.eyeScaleY,
      arch: pose.eyeArch,
      slant: pose.eyeSlant,
      blink: blink,
      color: color,
      core: core,
    );
    _drawEye(
      canvas,
      center: Offset(
        792 + pose.gazeX * 30 + idleGazeX,
        605 + pose.gazeY * 18 + idleGazeY,
      ),
      scaleX: pose.eyeScaleX * pose.rightEyeScale,
      scaleY: pose.eyeScaleY,
      arch: pose.eyeArch,
      slant: pose.eyeSlant,
      blink: pose.wink > 0.5 ? 1.0 : blink,
      color: color,
      core: core,
    );

    _drawNose(canvas, color, core, pose.noseScale, time);
    _drawMouth(canvas, color, core, time);
    canvas.restore();
  }

  double _blinkAmount(double t) {
    // A short natural blink roughly every 3.7-4.2 seconds.
    final phase = (t % 4.0);
    if (phase < 0.12) return 0;
    if (phase < 0.20) return math.sin(((phase - 0.12) / 0.08) * math.pi);
    return 0;
  }

  void _drawEye(
    Canvas canvas, {
    required Offset center,
    required double scaleX,
    required double scaleY,
    required double arch,
    required double slant,
    required double blink,
    required Color color,
    required Color core,
  }) {
    final width = 142 * scaleX;
    final height = 104 * scaleY * (1 - blink * 0.94);
    canvas.save();
    canvas.translate(center.dx, center.dy);

    if (arch > 0.55 || height < 12) {
      final path =
          Path()
            ..moveTo(-width * 0.48, 10)
            ..quadraticBezierTo(
              0,
              -54 * math.max(arch, 0.55).toDouble(),
              width * 0.48,
              10,
            );
      _stroke
        ..color = color
        ..strokeWidth = 18
        ..maskFilter = null;
      _glow
        ..color = color.withOpacity(0.72)
        ..strokeWidth = 25;
      canvas.drawPath(path, _glow);
      canvas.drawPath(path, _stroke);
      canvas.restore();
      return;
    }

    if (slant.abs() > 0.22) {
      final path =
          Path()
            ..moveTo(-width * 0.48, -height * 0.12 - slant * 24)
            ..lineTo(width * 0.48, height * 0.12 + slant * 24);
      _stroke
        ..color = color
        ..strokeWidth = math.max(12.0, height * 0.28).toDouble()
        ..maskFilter = null;
      _glow
        ..color = color.withOpacity(0.68)
        ..strokeWidth = math.max(22.0, height * 0.4).toDouble();
      canvas.drawPath(path, _glow);
      canvas.drawPath(path, _stroke);
      canvas.restore();
      return;
    }

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: math.max(5.0, height).toDouble(),
    );
    final radius = Radius.circular((math.min(width, height) * 0.42).toDouble());
    final rrect = RRect.fromRectAndRadius(rect, radius);
    _fill
      ..color = color.withOpacity(0.32)
      ..maskFilter = null;
    _glow
      ..color = color.withOpacity(0.65)
      ..strokeWidth = 12;
    canvas.drawRRect(rrect, _glow);
    _fill.color = color;
    canvas.drawRRect(rrect, _fill);
    final inner = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: width * 0.38,
        height: height * 0.48,
      ),
      Radius.circular(width * 0.12),
    );
    _fill.color = core.withOpacity(0.92);
    canvas.drawRRect(inner, _fill);
    canvas.restore();
  }

  void _drawNose(
    Canvas canvas,
    Color color,
    Color core,
    double scale,
    double t,
  ) {
    final pulse = 0.92 + 0.08 * math.sin(t * 2.1);
    final rect = Rect.fromCenter(
      center: const Offset(627, 700),
      width: 25 * scale * pulse,
      height: 17 * scale * pulse,
    );
    _fill
      ..color = color
      ..maskFilter = null;
    _glow
      ..color = color.withOpacity(0.7)
      ..strokeWidth = 12;
    canvas.drawOval(rect, _glow);
    canvas.drawOval(rect, _fill);
    _fill.color = core.withOpacity(0.8);
    canvas.drawOval(
      Rect.fromCenter(
        center: rect.center,
        width: rect.width * 0.42,
        height: rect.height * 0.42,
      ),
      _fill,
    );
  }

  void _drawMouth(Canvas canvas, Color color, Color core, double t) {
    final speaking = state == FaceState.speaking;
    final speakPulse =
        speaking
            ? (0.12 + 0.58 * volume + 0.12 * (0.5 + 0.5 * math.sin(t * 12.5)))
            : pose.mouthOpen;
    final open = speakPulse.clamp(0.0, 1.0).toDouble();
    final width = 158 * pose.mouthWidth;
    const center = Offset(627, 778);

    if (pose.mouthRoundness > 0.55) {
      final rect = Rect.fromCenter(
        center: center,
        width: width * 0.56,
        height: 38 + 88 * math.max(open, 0.2),
      );
      _fill
        ..color = color
        ..maskFilter = null;
      _glow
        ..color = color.withOpacity(0.68)
        ..strokeWidth = 18;
      canvas.drawOval(rect, _glow);
      canvas.drawOval(rect, _fill);
      return;
    }

    if (open > 0.08) {
      final mouthHeight = 18 + open * 108;
      final path =
          Path()
            ..moveTo(center.dx - width / 2, center.dy - 5)
            ..quadraticBezierTo(
              center.dx,
              center.dy + mouthHeight * 1.35,
              center.dx + width / 2,
              center.dy - 5,
            )
            ..quadraticBezierTo(
              center.dx,
              center.dy + mouthHeight * 0.62,
              center.dx - width / 2,
              center.dy - 5,
            )
            ..close();
      _fill
        ..color = color
        ..maskFilter = null;
      _glow
        ..color = color.withOpacity(0.65)
        ..strokeWidth = 18;
      canvas.drawPath(path, _glow);
      canvas.drawPath(path, _fill);
      return;
    }

    final path =
        Path()
          ..moveTo(center.dx - width / 2, center.dy)
          ..quadraticBezierTo(
            center.dx,
            center.dy + pose.mouthCurve * 34,
            center.dx + width / 2,
            center.dy,
          );
    _stroke
      ..color = color
      ..strokeWidth = 15
      ..maskFilter = null;
    _glow
      ..color = color.withOpacity(0.68)
      ..strokeWidth = 23;
    canvas.drawPath(path, _glow);
    canvas.drawPath(path, _stroke);
  }

  @override
  bool shouldRepaint(covariant _BotAiFacePainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.time != time ||
      oldDelegate.state != state ||
      oldDelegate.volume != volume ||
      oldDelegate.color != color;
}
