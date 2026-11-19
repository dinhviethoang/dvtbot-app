import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/xiaozhi_service.dart';
import '../utils/app_theme.dart';
import 'robot_face.dart';

/// Widget Avatar AI động phản hồi theo trạng thái (idle, listening, thinking, speaking)
/// và biểu cảm cảm xúc (happy, sad, thinking, angry, surprised, neutral...) của robot Xiaozhi.
class AiAvatarWidget extends StatefulWidget {
  final FaceState state;
  final String emotion;
  final double size;
  final bool showGlow;
  final XiaozhiService? service;

  const AiAvatarWidget({
    super.key,
    this.state = FaceState.idle,
    this.emotion = 'neutral',
    this.size = 40.0,
    this.showGlow = true,
    this.service,
  });

  @override
  State<AiAvatarWidget> createState() => _AiAvatarWidgetState();
}

class _AiAvatarWidgetState extends State<AiAvatarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late FaceState _currentState;
  late String _currentEmotion;

  @override
  void initState() {
    super.initState();
    _currentState = widget.state;
    _currentEmotion = widget.emotion;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _bindService();
  }

  void _bindService() {
    widget.service?.emotionNotifier.addListener(_onServiceEmotionChanged);
  }

  void _unbindService() {
    widget.service?.emotionNotifier.removeListener(_onServiceEmotionChanged);
  }

  void _onServiceEmotionChanged() {
    if (mounted && widget.service != null) {
      setState(() {
        _currentEmotion = widget.service!.emotionNotifier.value;
      });
    }
  }

  @override
  void didUpdateWidget(covariant AiAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      oldWidget.service?.emotionNotifier.removeListener(
        _onServiceEmotionChanged,
      );
      _bindService();
    }
    if (oldWidget.state != widget.state) {
      _currentState = widget.state;
    }
    if (oldWidget.emotion != widget.emotion) {
      _currentEmotion = widget.emotion;
    }
  }

  @override
  void dispose() {
    _unbindService();
    _animController.dispose();
    super.dispose();
  }

  Color _getStateColor() {
    switch (_currentState) {
      case FaceState.listening:
        return const Color(0xFF00E676); // Xanh lá sáng khi đang nghe
      case FaceState.speaking:
        return const Color(0xFF00F0FF); // Cyan phát sáng khi đang nói
      case FaceState.thinking:
        return const Color(0xFFA855F7); // Tím neon khi đang suy nghĩ
      case FaceState.error:
        return const Color(0xFFFF1744); // Đỏ khi lỗi
      case FaceState.connecting:
        return const Color(0xFFFFB300); // Vàng hổ phách khi kết nối
      case FaceState.idle:
      default:
        if (_currentEmotion.toLowerCase() == 'happy' ||
            _currentEmotion.toLowerCase() == 'laughing') {
          return const Color(0xFFFFD700); // Vàng kim khi vui
        } else if (_currentEmotion.toLowerCase() == 'sad') {
          return const Color(0xFF60A5FA); // Xanh dương dịu khi buồn
        }
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateColor = _getStateColor();
    final double radius = widget.size / 2;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final double progress = _animController.value;
        final double pulse = math.sin(progress * 2 * math.pi);

        // Hiệu ứng nhấp nháy viền khi listening, sóng âm khi speaking
        final double glowRadius =
            widget.showGlow
                ? (_currentState == FaceState.listening ||
                        _currentState == FaceState.speaking
                    ? 4.0 + pulse * 3.0
                    : 2.0)
                : 0.0;

        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0B101B),
            border: Border.all(color: stateColor.withOpacity(0.8), width: 1.5),
            boxShadow: [
              if (widget.showGlow)
                BoxShadow(
                  color: stateColor.withOpacity(
                    _currentState == FaceState.speaking
                        ? 0.5 + pulse.abs() * 0.3
                        : 0.3,
                  ),
                  blurRadius: glowRadius,
                  spreadRadius: _currentState == FaceState.speaking ? 1.5 : 0.5,
                ),
            ],
          ),
          child: ClipOval(
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _AiAvatarPainter(
                state: _currentState,
                emotion: _currentEmotion,
                color: stateColor,
                progress: progress,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AiAvatarPainter extends CustomPainter {
  final FaceState state;
  final String emotion;
  final Color color;
  final double progress;

  _AiAvatarPainter({
    required this.state,
    required this.emotion,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    final Paint eyePaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final Paint strokePaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, size.width * 0.05)
          ..strokeCap = StrokeCap.round;

    final emo = emotion.toLowerCase();
    final bool isSpeaking = state == FaceState.speaking;
    final bool isListening = state == FaceState.listening;
    final bool isThinking = state == FaceState.thinking;

    // 1. Vẽ mắt (trái & phải)
    final double eyeSpacing = size.width * 0.22;
    final double eyeY = cy - size.height * 0.08;
    final double eyeRadius = size.width * 0.10;

    // Chớp mắt ngẫu nhiên khi idle
    final bool isBlinking = (state == FaceState.idle) && (progress > 0.92);

    if (emo == 'happy' || emo == 'laughing') {
      // Mắt hình cánh cung vui vẻ ^ ^
      final pathLeft = Path();
      pathLeft.moveTo(cx - eyeSpacing - eyeRadius, eyeY);
      pathLeft.quadraticBezierTo(
        cx - eyeSpacing,
        eyeY - eyeRadius * 1.3,
        cx - eyeSpacing + eyeRadius,
        eyeY,
      );
      canvas.drawPath(pathLeft, strokePaint);

      final pathRight = Path();
      pathRight.moveTo(cx + eyeSpacing - eyeRadius, eyeY);
      pathRight.quadraticBezierTo(
        cx + eyeSpacing,
        eyeY - eyeRadius * 1.3,
        cx + eyeSpacing + eyeRadius,
        eyeY,
      );
      canvas.drawPath(pathRight, strokePaint);
    } else if (emo == 'sad' || emo == 'crying') {
      // Mắt buồn sụp xuống
      final pathLeft = Path();
      pathLeft.moveTo(cx - eyeSpacing - eyeRadius, eyeY - eyeRadius * 0.5);
      pathLeft.quadraticBezierTo(
        cx - eyeSpacing,
        eyeY + eyeRadius * 0.8,
        cx - eyeSpacing + eyeRadius,
        eyeY,
      );
      canvas.drawPath(pathLeft, strokePaint);

      final pathRight = Path();
      pathRight.moveTo(cx + eyeSpacing + eyeRadius, eyeY - eyeRadius * 0.5);
      pathRight.quadraticBezierTo(
        cx + eyeSpacing,
        eyeY + eyeRadius * 0.8,
        cx + eyeSpacing - eyeRadius,
        eyeY,
      );
      canvas.drawPath(pathRight, strokePaint);
    } else if (emo == 'angry') {
      // Mắt tức giận chéo vào trong
      canvas.drawLine(
        Offset(cx - eyeSpacing - eyeRadius, eyeY - eyeRadius),
        Offset(cx - eyeSpacing + eyeRadius, eyeY + eyeRadius * 0.5),
        strokePaint,
      );
      canvas.drawLine(
        Offset(cx + eyeSpacing + eyeRadius, eyeY - eyeRadius),
        Offset(cx + eyeSpacing - eyeRadius, eyeY + eyeRadius * 0.5),
        strokePaint,
      );
    } else if (emo == 'surprised') {
      // Mắt tròn xoe
      canvas.drawCircle(
        Offset(cx - eyeSpacing, eyeY),
        eyeRadius * 1.2,
        strokePaint,
      );
      canvas.drawCircle(
        Offset(cx + eyeSpacing, eyeY),
        eyeRadius * 1.2,
        strokePaint,
      );
    } else if (isBlinking) {
      // Nhắm mắt một chút
      canvas.drawLine(
        Offset(cx - eyeSpacing - eyeRadius, eyeY),
        Offset(cx - eyeSpacing + eyeRadius, eyeY),
        strokePaint,
      );
      canvas.drawLine(
        Offset(cx + eyeSpacing - eyeRadius, eyeY),
        Offset(cx + eyeSpacing + eyeRadius, eyeY),
        strokePaint,
      );
    } else {
      // Mắt tròn tiêu chuẩn (nhấp nháy / sáng hơn khi listening)
      final double currentEyeR =
          isListening
              ? eyeRadius * (1.0 + 0.25 * math.sin(progress * 2 * math.pi))
              : eyeRadius;
      canvas.drawCircle(Offset(cx - eyeSpacing, eyeY), currentEyeR, eyePaint);
      canvas.drawCircle(Offset(cx + eyeSpacing, eyeY), currentEyeR, eyePaint);
    }

    // 2. Vẽ miệng (Mouth)
    final double mouthY = cy + size.height * 0.22;
    final double mouthWidth = size.width * 0.28;

    if (isSpeaking) {
      // Miệng mấp máy theo nhịp sóng âm sine wave
      final double mouthOpen =
          (math.sin(progress * 4 * math.pi).abs() * size.height * 0.16) + 2.0;
      final Rect mouthRect = Rect.fromCenter(
        center: Offset(cx, mouthY),
        width: mouthWidth * (0.8 + 0.2 * math.sin(progress * 2 * math.pi)),
        height: mouthOpen,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(mouthRect, Radius.circular(mouthOpen / 2)),
        eyePaint,
      );
    } else if (isListening) {
      // Đang nghe: Miệng vẽ thanh sóng âm mini
      final double wave1 =
          math.sin(progress * 3 * math.pi).abs() * size.height * 0.08;
      final double wave2 =
          math.cos(progress * 3 * math.pi).abs() * size.height * 0.08;
      canvas.drawLine(
        Offset(cx - mouthWidth * 0.4, mouthY - wave1),
        Offset(cx - mouthWidth * 0.4, mouthY + wave1),
        strokePaint,
      );
      canvas.drawLine(
        Offset(cx, mouthY - wave2 * 1.4),
        Offset(cx, mouthY + wave2 * 1.4),
        strokePaint,
      );
      canvas.drawLine(
        Offset(cx + mouthWidth * 0.4, mouthY - wave1),
        Offset(cx + mouthWidth * 0.4, mouthY + wave1),
        strokePaint,
      );
    } else if (isThinking) {
      // Đang suy nghĩ: Miệng gợn sóng nhỏ
      final double waveY = mouthY + math.sin(progress * 2 * math.pi) * 2;
      canvas.drawLine(
        Offset(cx - mouthWidth * 0.35, waveY),
        Offset(cx + mouthWidth * 0.35, waveY),
        strokePaint,
      );
    } else if (emo == 'happy' || emo == 'laughing') {
      // Cười tươi
      final mouthPath = Path();
      mouthPath.moveTo(cx - mouthWidth * 0.5, mouthY - 2);
      mouthPath.quadraticBezierTo(
        cx,
        mouthY + size.height * 0.14,
        cx + mouthWidth * 0.5,
        mouthY - 2,
      );
      canvas.drawPath(mouthPath, strokePaint);
    } else if (emo == 'sad' || emo == 'crying') {
      // Miệng mếu
      final mouthPath = Path();
      mouthPath.moveTo(cx - mouthWidth * 0.4, mouthY + 4);
      mouthPath.quadraticBezierTo(
        cx,
        mouthY - size.height * 0.08,
        cx + mouthWidth * 0.4,
        mouthY + 4,
      );
      canvas.drawPath(mouthPath, strokePaint);
    } else {
      // Mỉm cười robot nhẹ nhàng
      final mouthPath = Path();
      mouthPath.moveTo(cx - mouthWidth * 0.4, mouthY);
      mouthPath.quadraticBezierTo(
        cx,
        mouthY + size.height * 0.06,
        cx + mouthWidth * 0.4,
        mouthY,
      );
      canvas.drawPath(mouthPath, strokePaint);
    }

    // 3. Hiệu ứng thinking xoay quanh nếu đang suy nghĩ
    if (isThinking) {
      final double orbitR = r * 0.85;
      final double angle = progress * 2 * math.pi;
      final double dotX = cx + orbitR * math.cos(angle);
      final double dotY = cy + orbitR * math.sin(angle);
      canvas.drawCircle(Offset(dotX, dotY), size.width * 0.04, eyePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AiAvatarPainter oldDelegate) => true;
}
