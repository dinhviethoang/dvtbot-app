/// RobotFace - Giao diện khuôn mặt robot AI botAi cho Samsung J2 Pro
/// Thiết kế Mecha Cyberpunk cơ khí tự thiết kế (2 mắt lớn + 1 miệng trên nền đen #000000).
/// Tối ưu cho màn hình nằm ngang (landscape 960x540) và máy yếu (RAM 1.5GB):
/// - Sử dụng 1 AnimationController lặp duy nhất, bọc RepaintBoundary
/// - Tái sử dụng đối tượng Paint/Path trong CustomPainter, hạn chế tối đa rác bộ nhớ
/// - Hiệu ứng viền phát sáng cyan (#00F0FF) / đỏ (#FF1744) với sigma <= 4
/// - Nội suy tham số chuyển cảm xúc/trạng thái mượt mà trong ~280ms

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Các trạng thái hoạt động của robot
enum FaceState {
  idle,
  connecting,
  listening,
  thinking,
  speaking,
  error,
  standby,
  wakeDetected,
  executing,
}

/// Các biểu cảm cảm xúc của robot
enum FaceEmotion {
  neutral,
  happy,
  laughing,
  sad,
  angry,
  surprised,
  loving,
  sleepy,
  confused,
  winking,
  cool,
  thinking,
}

/// Widget hiển thị khuôn mặt robot Mecha toàn màn hình
class RobotFace extends StatefulWidget {
  final FaceState state;
  final FaceEmotion emotion;
  final double volume;
  final Color color;

  const RobotFace({
    super.key,
    required this.state,
    this.emotion = FaceEmotion.neutral,
    this.volume = 0.0,
    this.color = const Color(0xFF00F0FF),
  });

  /// Chuyển đổi tên cảm xúc từ server Xiaozhi sang enum [FaceEmotion]
  static FaceEmotion faceEmotionFromServer(String? s) {
    if (s == null) return FaceEmotion.neutral;
    switch (s.trim().toLowerCase()) {
      case 'happy':
      case 'relaxed':
      case 'delicious':
        return FaceEmotion.happy;
      case 'laughing':
      case 'funny':
        return FaceEmotion.laughing;
      case 'sad':
      case 'crying':
        return FaceEmotion.sad;
      case 'angry':
        return FaceEmotion.angry;
      case 'surprised':
      case 'shocked':
        return FaceEmotion.surprised;
      case 'loving':
      case 'kissy':
        return FaceEmotion.loving;
      case 'sleepy':
        return FaceEmotion.sleepy;
      case 'confused':
      case 'embarrassed':
        return FaceEmotion.confused;
      case 'winking':
      case 'silly':
        return FaceEmotion.winking;
      case 'cool':
      case 'confident':
        return FaceEmotion.cool;
      case 'thinking':
        return FaceEmotion.thinking;
      case 'neutral':
      default:
        return FaceEmotion.neutral;
    }
  }

  @override
  State<RobotFace> createState() => _RobotFaceState();
}

class _RobotFaceState extends State<RobotFace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late _FaceParams _fromSnapshot;
  late _FaceParams _toSnapshot;
  DateTime _transitionStartTime = DateTime.now();
  static const Duration _transitionDuration = Duration(milliseconds: 280);

  // Bộ đếm thời gian chớp mắt ngẫu nhiên khi idle (2 - 6 giây)
  double _lastBlinkTime = 0.0;
  double _nextBlinkInterval = 3.2;
  final math.Random _random = math.Random();

  late final _RobotFacePainter _painter;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _toSnapshot = _buildTargetParams(
      widget.emotion,
      widget.state,
      widget.color,
    );
    _fromSnapshot = _toSnapshot;
    _transitionStartTime = DateTime.now();

    _painter = _RobotFacePainter();
  }

  @override
  void didUpdateWidget(covariant RobotFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emotion != widget.emotion ||
        oldWidget.state != widget.state ||
        oldWidget.color != widget.color) {
      _fromSnapshot = _getCurrentInterpolatedParams();
      _toSnapshot = _buildTargetParams(
        widget.emotion,
        widget.state,
        widget.color,
      );
      _transitionStartTime = DateTime.now();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _FaceParams _getCurrentInterpolatedParams() {
    final elapsed =
        DateTime.now().difference(_transitionStartTime).inMilliseconds;
    final double t = (elapsed / _transitionDuration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
    final double curveT = Curves.easeInOutCubic.transform(t);
    return _FaceParams.lerp(_fromSnapshot, _toSnapshot, curveT);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        color: const Color(0xFF000000),
        width: double.infinity,
        height: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final double nowSec =
                DateTime.now().millisecondsSinceEpoch / 1000.0;
            final currentParams = _getCurrentInterpolatedParams();

            // Tính toán chớp mắt tự nhiên khi idle
            double blinkFactor = 0.0;
            double idleGazeX = 0.0;
            double idleGazeY = 0.0;

            if (widget.state == FaceState.idle) {
              final diff = nowSec - _lastBlinkTime;
              if (diff >= _nextBlinkInterval &&
                  diff < _nextBlinkInterval + 0.16) {
                final bt = (diff - _nextBlinkInterval) / 0.16;
                blinkFactor = math.sin(bt * math.pi);
              } else if (diff >= _nextBlinkInterval + 0.16) {
                _lastBlinkTime = nowSec;
                _nextBlinkInterval = 2.0 + _random.nextDouble() * 4.0;
              }

              // Đảo mắt nhẹ nhàng
              idleGazeX =
                  math.sin(nowSec * 0.75) * 0.14 +
                  math.sin(nowSec * 0.28) * 0.08;
              idleGazeY = math.cos(nowSec * 0.42) * 0.06;
            }

            _painter.update(
              params: currentParams,
              timeSeconds: nowSec,
              state: widget.state,
              volume: widget.volume.clamp(0.0, 1.0),
              blinkFactor: blinkFactor,
              idleGazeX: idleGazeX,
              idleGazeY: idleGazeY,
            );

            return CustomPaint(painter: _painter, size: Size.infinite);
          },
        ),
      ),
    );
  }

  static _FaceParams _buildTargetParams(
    FaceEmotion emotion,
    FaceState state,
    Color baseColor,
  ) {
    Color activeColor =
        (state == FaceState.error) ? const Color(0xFFFF1744) : baseColor;

    // Tăng độ tương phản nhận diện cảm xúc từ xa 2 mét
    if (state != FaceState.error) {
      if (emotion == FaceEmotion.angry) {
        activeColor = const Color(
          0xFFFF6B35,
        ); // Cam đỏ nhẹ đặc trưng giận dữ thay vì cyan
      } else if (emotion == FaceEmotion.sad) {
        activeColor = const Color(0xFF64B5F6); // Xanh nhạt đượm buồn
      }
    }

    double eyeScaleX = 1.0;
    double eyeScaleY = 1.0;
    double eyeSlantLeft = 0.0;
    double eyeSlantRight = 0.0;
    double eyeOpenRatio = 1.0;
    double eyeArch = 0.0;
    double eyeHeart = 0.0;
    double eyeXShape = (state == FaceState.error) ? 1.0 : 0.0;
    double irisOffsetX = 0.0;
    double irisOffsetY = 0.0;
    double irisScale = 1.0;
    double leftEyeScale = 1.0;
    double rightEyeScale = 1.0;
    double rightEyeWink = 0.0;

    double mouthWidth = 1.0;
    double mouthHeight = 1.0;
    double mouthCurve = 0.15;
    double mouthRoundness = 0.0;
    double mouthOpen = 0.0;
    double mouthSkew = 0.0;
    double glowIntensity = 0.92;

    switch (emotion) {
      case FaceEmotion.happy:
        eyeArch = 1.0; // Mắt ^ ^
        mouthCurve = 0.90;
        mouthOpen = 0.32;
        mouthWidth = 1.18; // Miệng cười rộng
        break;
      case FaceEmotion.laughing:
        eyeArch = 1.0;
        eyeScaleX = 1.08;
        eyeScaleY = 1.08;
        mouthCurve = 0.92;
        mouthOpen = 0.75;
        mouthWidth = 1.25;
        break;
      case FaceEmotion.sad:
        eyeSlantLeft = -0.28;
        eyeSlantRight = -0.28;
        eyeScaleY = 0.72;
        eyeOpenRatio = 0.80; // Mí sụp xuống
        irisOffsetY = 0.35; // Mắt nhìn xuống
        mouthCurve = -0.85; // Miệng cong vòng xuống rõ rệt
        mouthWidth = 0.85;
        break;
      case FaceEmotion.angry:
        eyeSlantLeft = 0.38; // Lông mày/mắt xiên mạnh
        eyeSlantRight = 0.38;
        eyeScaleY = 0.78;
        irisScale = 0.82;
        mouthCurve = -0.52;
        mouthSkew = -0.28; // Miệng méo bất mãn
        mouthWidth = 0.95;
        break;
      case FaceEmotion.surprised:
        eyeScaleX = 1.28;
        eyeScaleY = 1.32;
        irisScale = 1.25;
        mouthRoundness = 1.0; // Miệng chữ O tròn xoe
        mouthOpen = 0.82;
        mouthWidth = 0.70;
        break;
      case FaceEmotion.loving:
        eyeHeart = 1.0;
        mouthCurve = 0.65;
        mouthOpen = 0.18;
        break;
      case FaceEmotion.sleepy:
        eyeScaleY = 0.35;
        irisOffsetY = 0.16;
        mouthCurve = 0.05;
        mouthWidth = 0.65;
        break;
      case FaceEmotion.confused:
        leftEyeScale = 1.22;
        rightEyeScale = 0.72;
        eyeSlantLeft = 0.08;
        eyeSlantRight = -0.16;
        irisOffsetX = 0.15;
        mouthSkew = 0.48;
        mouthCurve = 0.12;
        break;
      case FaceEmotion.winking:
        rightEyeWink = 1.0;
        eyeArch = 0.35;
        mouthCurve = 0.68;
        mouthSkew = 0.32;
        break;
      case FaceEmotion.cool:
        eyeScaleY = 0.42;
        eyeScaleX = 1.15;
        mouthCurve = 0.28;
        mouthSkew = 0.30;
        mouthWidth = 0.95;
        break;
      case FaceEmotion.thinking:
        irisOffsetX = 0.52;
        irisOffsetY = -0.58;
        eyeSlantLeft = -0.06;
        mouthCurve = -0.12;
        mouthWidth = 0.75;
        mouthSkew = -0.22;
        break;
      case FaceEmotion.neutral:
        break;
    }

    // Hiệu chỉnh theo trạng thái hoạt động
    switch (state) {
      case FaceState.listening:
        eyeScaleX *= 1.12;
        eyeScaleY *= 1.12;
        glowIntensity = 1.0;
        break;
      case FaceState.connecting:
        glowIntensity = 0.55;
        eyeScaleY *= 0.92;
        break;
      case FaceState.thinking:
        irisOffsetY = -0.55;
        irisOffsetX = 0.45;
        break;
      case FaceState.speaking:
        mouthOpen = 0.45;
        break;
      case FaceState.error:
        eyeXShape = 1.0;
        activeColor = const Color(0xFFFF1744);
        mouthCurve = -0.35;
        mouthOpen = 0.0;
        break;
      case FaceState.standby:
        eyeOpenRatio = 0.40;
        glowIntensity = 0.35;
        eyeScaleY *= 0.85;
        break;
      case FaceState.wakeDetected:
        eyeScaleX *= 1.25;
        eyeScaleY *= 1.25;
        glowIntensity = 1.30;
        activeColor = const Color(0xFF00FFFF);
        mouthCurve = 0.20;
        break;
      case FaceState.executing:
        irisOffsetY = 0.20;
        glowIntensity = 1.0;
        eyeScaleX *= 1.08;
        eyeScaleY *= 1.08;
        break;
      case FaceState.idle:
        break;
    }

    return _FaceParams(
      eyeScaleX: eyeScaleX,
      eyeScaleY: eyeScaleY,
      eyeSlantLeft: eyeSlantLeft,
      eyeSlantRight: eyeSlantRight,
      eyeOpenRatio: eyeOpenRatio,
      eyeArch: eyeArch,
      eyeHeart: eyeHeart,
      eyeXShape: eyeXShape,
      irisOffsetX: irisOffsetX,
      irisOffsetY: irisOffsetY,
      irisScale: irisScale,
      leftEyeScale: leftEyeScale,
      rightEyeScale: rightEyeScale,
      rightEyeWink: rightEyeWink,
      mouthWidth: mouthWidth,
      mouthHeight: mouthHeight,
      mouthCurve: mouthCurve,
      mouthRoundness: mouthRoundness,
      mouthOpen: mouthOpen,
      mouthSkew: mouthSkew,
      baseColor: activeColor,
      glowIntensity: glowIntensity,
    );
  }
}

/// Lớp lưu trữ các tham số hình học của khuôn mặt để nội suy mượt mà
class _FaceParams {
  final double eyeScaleX;
  final double eyeScaleY;
  final double eyeSlantLeft;
  final double eyeSlantRight;
  final double eyeOpenRatio;
  final double eyeArch;
  final double eyeHeart;
  final double eyeXShape;
  final double irisOffsetX;
  final double irisOffsetY;
  final double irisScale;
  final double leftEyeScale;
  final double rightEyeScale;
  final double rightEyeWink;
  final double mouthWidth;
  final double mouthHeight;
  final double mouthCurve;
  final double mouthRoundness;
  final double mouthOpen;
  final double mouthSkew;
  final Color baseColor;
  final double glowIntensity;

  const _FaceParams({
    this.eyeScaleX = 1.0,
    this.eyeScaleY = 1.0,
    this.eyeSlantLeft = 0.0,
    this.eyeSlantRight = 0.0,
    this.eyeOpenRatio = 1.0,
    this.eyeArch = 0.0,
    this.eyeHeart = 0.0,
    this.eyeXShape = 0.0,
    this.irisOffsetX = 0.0,
    this.irisOffsetY = 0.0,
    this.irisScale = 1.0,
    this.leftEyeScale = 1.0,
    this.rightEyeScale = 1.0,
    this.rightEyeWink = 0.0,
    this.mouthWidth = 1.0,
    this.mouthHeight = 1.0,
    this.mouthCurve = 0.15,
    this.mouthRoundness = 0.0,
    this.mouthOpen = 0.0,
    this.mouthSkew = 0.0,
    this.baseColor = const Color(0xFF00F0FF),
    this.glowIntensity = 0.9,
  });

  static _FaceParams lerp(_FaceParams a, _FaceParams b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    return _FaceParams(
      eyeScaleX: l(a.eyeScaleX, b.eyeScaleX),
      eyeScaleY: l(a.eyeScaleY, b.eyeScaleY),
      eyeSlantLeft: l(a.eyeSlantLeft, b.eyeSlantLeft),
      eyeSlantRight: l(a.eyeSlantRight, b.eyeSlantRight),
      eyeOpenRatio: l(a.eyeOpenRatio, b.eyeOpenRatio),
      eyeArch: l(a.eyeArch, b.eyeArch),
      eyeHeart: l(a.eyeHeart, b.eyeHeart),
      eyeXShape: l(a.eyeXShape, b.eyeXShape),
      irisOffsetX: l(a.irisOffsetX, b.irisOffsetX),
      irisOffsetY: l(a.irisOffsetY, b.irisOffsetY),
      irisScale: l(a.irisScale, b.irisScale),
      leftEyeScale: l(a.leftEyeScale, b.leftEyeScale),
      rightEyeScale: l(a.rightEyeScale, b.rightEyeScale),
      rightEyeWink: l(a.rightEyeWink, b.rightEyeWink),
      mouthWidth: l(a.mouthWidth, b.mouthWidth),
      mouthHeight: l(a.mouthHeight, b.mouthHeight),
      mouthCurve: l(a.mouthCurve, b.mouthCurve),
      mouthRoundness: l(a.mouthRoundness, b.mouthRoundness),
      mouthOpen: l(a.mouthOpen, b.mouthOpen),
      mouthSkew: l(a.mouthSkew, b.mouthSkew),
      baseColor: Color.lerp(a.baseColor, b.baseColor, t) ?? b.baseColor,
      glowIntensity: l(a.glowIntensity, b.glowIntensity),
    );
  }
}

/// CustomPainter vẽ đôi mắt và khuôn miệng robot Mecha
/// Tối ưu tuyệt đối: tái sử dụng toàn bộ Paint và Path
class _RobotFacePainter extends CustomPainter {
  _FaceParams _params = const _FaceParams();
  double _timeSeconds = 0.0;
  FaceState _state = FaceState.idle;
  double _volume = 0.0;
  double _blinkFactor = 0.0;
  double _idleGazeX = 0.0;
  double _idleGazeY = 0.0;

  // Tái sử dụng đối tượng Paint để không tạo rác bộ nhớ
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _strokePaint = Paint()..style = PaintingStyle.stroke;
  final Paint _coreStrokePaint = Paint()..style = PaintingStyle.stroke;
  final Paint _glowStrokePaint = Paint()..style = PaintingStyle.stroke;

  // Tái sử dụng Path
  final Path _path = Path();
  final Path _altPath = Path();

  void update({
    required _FaceParams params,
    required double timeSeconds,
    required FaceState state,
    required double volume,
    required double blinkFactor,
    required double idleGazeX,
    required double idleGazeY,
  }) {
    _params = params;
    _timeSeconds = timeSeconds;
    _state = state;
    _volume = volume;
    _blinkFactor = blinkFactor;
    _idleGazeX = idleGazeX;
    _idleGazeY = idleGazeY;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double w = size.width;
    final double h = size.height;
    final bool isLandscape = w >= h;

    // Tính toán bố cục màn hình nằm ngang (Samsung J2 Pro: 960x540)
    double leftEyeCx, rightEyeCx, eyeCy, eyeW, eyeH;
    double mouthCx, mouthCy, mouthBaseW, mouthBaseH;

    if (isLandscape) {
      final double eyeSpan = w * 0.34;
      leftEyeCx = w * 0.5 - eyeSpan * 0.5;
      rightEyeCx = w * 0.5 + eyeSpan * 0.5;
      eyeCy = h * 0.38;

      eyeW = (w * 0.17).clamp(90.0, 185.0);
      eyeH = (h * 0.36).clamp(85.0, 195.0);

      mouthCx = w * 0.5;
      mouthCy = h * 0.76;
      mouthBaseW = (w * 0.15).clamp(80.0, 160.0);
      mouthBaseH = (h * 0.10).clamp(24.0, 60.0);
    } else {
      // Màn hình dọc
      final double eyeSpan = w * 0.44;
      leftEyeCx = w * 0.5 - eyeSpan * 0.5;
      rightEyeCx = w * 0.5 + eyeSpan * 0.5;
      eyeCy = h * 0.35;

      eyeW = (w * 0.26).clamp(80.0, 160.0);
      eyeH = (w * 0.28).clamp(80.0, 180.0);

      mouthCx = w * 0.5;
      mouthCy = h * 0.65;
      mouthBaseW = (w * 0.28).clamp(80.0, 160.0);
      mouthBaseH = (h * 0.06).clamp(24.0, 60.0);
    }

    // Xử lý hiệu ứng động theo trạng thái
    double effectiveGlow = _params.glowIntensity;
    Color mainColor = _params.baseColor;

    if (_state == FaceState.connecting) {
      final breath = 0.35 + 0.45 * (0.5 + 0.5 * math.sin(_timeSeconds * 2.8));
      effectiveGlow *= breath;
    } else if (_state == FaceState.standby) {
      final breath = 0.25 + 0.35 * (0.5 + 0.5 * math.sin(_timeSeconds * 1.5));
      effectiveGlow *= breath;
    } else if (_state == FaceState.wakeDetected) {
      effectiveGlow = 1.35;
    } else if (_state == FaceState.executing) {
      final pulse = 0.75 + 0.25 * (0.5 + 0.5 * math.sin(_timeSeconds * 4.5));
      effectiveGlow *= pulse;
    } else if (_state == FaceState.error) {
      final flicker = (math.sin(_timeSeconds * 30.0) > -0.6) ? 1.0 : 0.45;
      effectiveGlow *= flicker;
    }

    final Color coreColor =
        Color.lerp(mainColor, Colors.white, 0.78) ?? Colors.white;

    // VẼ MẮT TRÁI
    _drawEye(
      canvas: canvas,
      cx: leftEyeCx,
      cy: eyeCy,
      baseW: eyeW,
      baseH: eyeH,
      isLeftEye: true,
      scaleMultiplier: _params.leftEyeScale,
      slantAngle: _params.eyeSlantLeft,
      mainColor: mainColor,
      coreColor: coreColor,
      glow: effectiveGlow,
    );

    // VẼ MẮT PHẢI
    _drawEye(
      canvas: canvas,
      cx: rightEyeCx,
      cy: eyeCy,
      baseW: eyeW,
      baseH: eyeH,
      isLeftEye: false,
      scaleMultiplier: _params.rightEyeScale,
      slantAngle: -_params.eyeSlantRight,
      mainColor: mainColor,
      coreColor: coreColor,
      glow: effectiveGlow,
    );

    // VẼ MIỆNG
    _drawMouth(
      canvas: canvas,
      cx: mouthCx,
      cy: mouthCy,
      baseW: mouthBaseW,
      baseH: mouthBaseH,
      mainColor: mainColor,
      coreColor: coreColor,
      glow: effectiveGlow,
    );
  }

  void _drawEye({
    required Canvas canvas,
    required double cx,
    required double cy,
    required double baseW,
    required double baseH,
    required bool isLeftEye,
    required double scaleMultiplier,
    required double slantAngle,
    required Color mainColor,
    required Color coreColor,
    required double glow,
  }) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(slantAngle);

    final double effectiveOpen =
        _params.eyeOpenRatio * (1.0 - _blinkFactor).clamp(0.02, 1.0);
    final double sx = _params.eyeScaleX * scaleMultiplier;
    final double sy = _params.eyeScaleY * scaleMultiplier * effectiveOpen;
    canvas.scale(sx, sy);

    final double hw = baseW * 0.5;
    final double hh = baseH * 0.5;

    final double eyeArch = _params.eyeArch;
    final double eyeHeart = _params.eyeHeart;
    final double eyeXShape = _params.eyeXShape;
    final double rightWink = (!isLeftEye) ? _params.rightEyeWink : 0.0;

    final double standardEyeAlpha = ((1.0 - eyeArch) *
            (1.0 - eyeHeart) *
            (1.0 - eyeXShape) *
            (1.0 - rightWink))
        .clamp(0.0, 1.0);

    // 1. Mắt chuẩn: Khối Mecha vát góc ngoài + mống mắt phát sáng
    if (standardEyeAlpha > 0.01) {
      _drawStandardMechaEye(
        canvas: canvas,
        hw: hw,
        hh: hh,
        isLeftEye: isLeftEye,
        alpha: standardEyeAlpha,
        mainColor: mainColor,
        coreColor: coreColor,
        glow: glow,
      );
    }

    // 2. Mắt cười: Vòng cung úp ngược (^ ^)
    if (eyeArch > 0.01) {
      _drawArchEye(
        canvas: canvas,
        hw: hw,
        hh: hh,
        alpha: eyeArch,
        mainColor: mainColor,
        coreColor: coreColor,
        glow: glow,
      );
    }

    // 3. Mắt yêu thương: Hình trái tim
    if (eyeHeart > 0.01) {
      _drawHeartEye(
        canvas: canvas,
        hw: hw,
        hh: hh,
        alpha: eyeHeart,
        mainColor: mainColor,
        coreColor: coreColor,
        glow: glow,
      );
    }

    // 4. Mắt lỗi: Hình chữ X Mecha
    if (eyeXShape > 0.01) {
      _drawXEye(
        canvas: canvas,
        hw: hw,
        hh: hh,
        alpha: eyeXShape,
        mainColor: mainColor,
        coreColor: coreColor,
        glow: glow,
      );
    }

    // 5. Mắt nháy bên phải
    if (rightWink > 0.01) {
      _drawWinkEye(
        canvas: canvas,
        hw: hw,
        hh: hh,
        alpha: rightWink,
        mainColor: mainColor,
        coreColor: coreColor,
        glow: glow,
      );
    }

    canvas.restore();
  }

  void _drawStandardMechaEye({
    required Canvas canvas,
    required double hw,
    required double hh,
    required bool isLeftEye,
    required double alpha,
    required Color mainColor,
    required Color coreColor,
    required double glow,
  }) {
    final double chamfer = (hw * 0.42).clamp(16.0, 32.0);
    final double radius = (hw * 0.30).clamp(12.0, 24.0);

    _path.reset();
    if (isLeftEye) {
      // Vát góc ngoài trên bên trái
      _path.moveTo(-hw + chamfer, -hh);
      _path.lineTo(hw - radius, -hh);
      _path.arcToPoint(
        Offset(hw, -hh + radius),
        radius: Radius.circular(radius),
      );
      _path.lineTo(hw, hh - radius);
      _path.arcToPoint(
        Offset(hw - radius, hh),
        radius: Radius.circular(radius),
      );
      _path.lineTo(-hw + radius, hh);
      _path.arcToPoint(
        Offset(-hw, hh - radius),
        radius: Radius.circular(radius),
      );
      _path.lineTo(-hw, -hh + chamfer);
      _path.lineTo(-hw + chamfer, -hh);
      _path.close();
    } else {
      // Vát góc ngoài trên bên phải
      _path.moveTo(-hw + radius, -hh);
      _path.lineTo(hw - chamfer, -hh);
      _path.lineTo(hw, -hh + chamfer);
      _path.lineTo(hw, hh - radius);
      _path.arcToPoint(
        Offset(hw - radius, hh),
        radius: Radius.circular(radius),
      );
      _path.lineTo(-hw + radius, hh);
      _path.arcToPoint(
        Offset(-hw, hh - radius),
        radius: Radius.circular(radius),
      );
      _path.lineTo(-hw, -hh + radius);
      _path.arcToPoint(
        Offset(-hw + radius, -hh),
        radius: Radius.circular(radius),
      );
      _path.close();
    }

    // Hốc mắt cơ khí tối màu
    _fillPaint
      ..color = const Color(0xFF030D12)
      ..maskFilter = null;
    canvas.drawPath(_path, _fillPaint);

    // MỐNG MẮT PHÁT SÁNG (được clip trong hốc mắt)
    canvas.save();
    canvas.clipPath(_path);

    // Tọa độ mống mắt
    double irisShiftX = (_params.irisOffsetX + _idleGazeX).clamp(-0.9, 0.9);
    double irisShiftY = (_params.irisOffsetY + _idleGazeY).clamp(-0.9, 0.9);

    if (_state == FaceState.thinking) {
      irisShiftX = 0.50 + math.cos(_timeSeconds * 2.2) * 0.12;
      irisShiftY = -0.55 + math.sin(_timeSeconds * 2.2) * 0.08;
    }

    final double ix = irisShiftX * hw * 0.40;
    final double iy = irisShiftY * hh * 0.40;
    final double iw = hw * 0.62 * _params.irisScale;
    final double ih = hh * 0.62 * _params.irisScale;

    // Quầng sáng mống mắt
    _fillPaint
      ..color = _withOpacity(mainColor, 0.25 * alpha * glow)
      ..maskFilter = null;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(ix, iy), width: iw, height: ih),
        Radius.circular(iw * 0.28),
      ),
      _fillPaint,
    );

    // Khung mống mắt
    _strokePaint
      ..color = _withOpacity(mainColor, 0.85 * alpha * glow)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.square
      ..maskFilter = null;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(ix, iy), width: iw, height: ih),
        Radius.circular(iw * 0.28),
      ),
      _strokePaint,
    );

    // Lõi con ngươi sáng trắng
    _fillPaint.color = _withOpacity(coreColor, 0.95 * alpha * glow);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(ix, iy),
          width: iw * 0.52,
          height: ih * 0.52,
        ),
        Radius.circular(iw * 0.18),
      ),
      _fillPaint,
    );

    // Khía rãnh Mecha quang học 2 bên mống mắt
    _strokePaint
      ..color = _withOpacity(mainColor, 0.75 * alpha * glow)
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(ix - iw * 0.60, iy),
      Offset(ix - iw * 0.42, iy),
      _strokePaint,
    );
    canvas.drawLine(
      Offset(ix + iw * 0.42, iy),
      Offset(ix + iw * 0.60, iy),
      _strokePaint,
    );

    canvas.restore(); // Hết clip mống mắt

    // Quầng sáng viền hốc mắt ngoài (sigma <= 4)
    _glowStrokePaint
      ..color = _withOpacity(mainColor, 0.35 * alpha * glow)
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3.0);
    canvas.drawPath(_path, _glowStrokePaint);

    // Nét viền neon chính
    _strokePaint
      ..color = _withOpacity(mainColor, 0.95 * alpha * glow)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter
      ..maskFilter = null;
    canvas.drawPath(_path, _strokePaint);

    // Điểm nhấn vát góc mecha
    _coreStrokePaint
      ..color = _withOpacity(coreColor, 0.85 * alpha * glow)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    if (isLeftEye) {
      canvas.drawLine(
        Offset(-hw + chamfer, -hh),
        Offset(-hw, -hh + chamfer),
        _coreStrokePaint,
      );
    } else {
      canvas.drawLine(
        Offset(hw - chamfer, -hh),
        Offset(hw, -hh + chamfer),
        _coreStrokePaint,
      );
    }
  }

  void _drawArchEye({
    required Canvas canvas,
    required double hw,
    required double hh,
    required double alpha,
    required Color mainColor,
    required Color coreColor,
    required double glow,
  }) {
    _altPath.reset();
    _altPath.moveTo(-hw * 0.85, hh * 0.28);
    _altPath.cubicTo(
      -hw * 0.35,
      -hh * 0.48,
      hw * 0.35,
      -hh * 0.48,
      hw * 0.85,
      hh * 0.28,
    );

    // Quầng sáng mờ ngoài
    _glowStrokePaint
      ..color = _withOpacity(mainColor, 0.38 * alpha * glow)
      ..strokeWidth = 18.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3.5);
    canvas.drawPath(_altPath, _glowStrokePaint);

    // Nét vòm chính
    _strokePaint
      ..color = _withOpacity(mainColor, 0.95 * alpha * glow)
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = null;
    canvas.drawPath(_altPath, _strokePaint);

    // Lõi phát sáng trắng
    _coreStrokePaint
      ..color = _withOpacity(coreColor, 0.95 * alpha * glow)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(_altPath, _coreStrokePaint);
  }

  void _drawHeartEye({
    required Canvas canvas,
    required double hw,
    required double hh,
    required double alpha,
    required Color mainColor,
    required Color coreColor,
    required double glow,
  }) {
    final double pulse = 1.0 + 0.05 * math.sin(_timeSeconds * 6.0);
    final double w = hw * 1.85 * pulse;
    final double h = hh * 1.85 * pulse;

    _altPath.reset();
    final double topY = -h * 0.35;
    final double botY = h * 0.42;
    final double midY = -h * 0.08;

    _altPath.moveTo(0, botY);
    _altPath.cubicTo(-w * 0.55, h * 0.10, -w * 0.58, topY, -w * 0.28, topY);
    _altPath.cubicTo(-w * 0.08, topY, 0, midY, 0, midY);
    _altPath.cubicTo(0, midY, w * 0.08, topY, w * 0.28, topY);
    _altPath.cubicTo(w * 0.58, topY, w * 0.55, h * 0.10, 0, botY);
    _altPath.close();

    _fillPaint
      ..color = _withOpacity(mainColor, 0.22 * alpha * glow)
      ..maskFilter = null;
    canvas.drawPath(_altPath, _fillPaint);

    _glowStrokePaint
      ..color = _withOpacity(mainColor, 0.40 * alpha * glow)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3.0);
    canvas.drawPath(_altPath, _glowStrokePaint);

    _strokePaint
      ..color = _withOpacity(mainColor, 0.95 * alpha * glow)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = null;
    canvas.drawPath(_altPath, _strokePaint);

    _coreStrokePaint
      ..color = _withOpacity(coreColor, 0.85 * alpha * glow)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(_altPath, _coreStrokePaint);
  }

  void _drawXEye({
    required Canvas canvas,
    required double hw,
    required double hh,
    required double alpha,
    required Color mainColor,
    required Color coreColor,
    required double glow,
  }) {
    final double spanX = hw * 0.72;
    final double spanY = hh * 0.72;

    _glowStrokePaint
      ..color = _withOpacity(mainColor, 0.45 * alpha * glow)
      ..strokeWidth = 16.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3.5);
    canvas.drawLine(
      Offset(-spanX, -spanY),
      Offset(spanX, spanY),
      _glowStrokePaint,
    );
    canvas.drawLine(
      Offset(-spanX, spanY),
      Offset(spanX, -spanY),
      _glowStrokePaint,
    );

    _strokePaint
      ..color = _withOpacity(mainColor, 0.95 * alpha * glow)
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = null;
    canvas.drawLine(Offset(-spanX, -spanY), Offset(spanX, spanY), _strokePaint);
    canvas.drawLine(Offset(-spanX, spanY), Offset(spanX, -spanY), _strokePaint);

    _coreStrokePaint
      ..color = _withOpacity(coreColor, 0.95 * alpha * glow)
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-spanX, -spanY),
      Offset(spanX, spanY),
      _coreStrokePaint,
    );
    canvas.drawLine(
      Offset(-spanX, spanY),
      Offset(spanX, -spanY),
      _coreStrokePaint,
    );
  }

  void _drawWinkEye({
    required Canvas canvas,
    required double hw,
    required double hh,
    required double alpha,
    required Color mainColor,
    required Color coreColor,
    required double glow,
  }) {
    _altPath.reset();
    _altPath.moveTo(-hw * 0.82, hh * 0.12);
    _altPath.quadraticBezierTo(0, -hh * 0.25, hw * 0.82, hh * 0.12);

    _glowStrokePaint
      ..color = _withOpacity(mainColor, 0.40 * alpha * glow)
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3.0);
    canvas.drawPath(_altPath, _glowStrokePaint);

    _strokePaint
      ..color = _withOpacity(mainColor, 0.95 * alpha * glow)
      ..strokeWidth = 7.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = null;
    canvas.drawPath(_altPath, _strokePaint);

    _coreStrokePaint
      ..color = _withOpacity(coreColor, 0.90 * alpha * glow)
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(_altPath, _coreStrokePaint);
  }

  void _drawMouth({
    required Canvas canvas,
    required double cx,
    required double cy,
    required double baseW,
    required double baseH,
    required Color mainColor,
    required Color coreColor,
    required double glow,
  }) {
    canvas.save();
    canvas.translate(cx, cy);

    final double mw2 = (baseW * _params.mouthWidth) * 0.5;
    final double mh = baseH * _params.mouthHeight;

    // Tính toán độ mở miệng khi đang nói hoặc theo cảm xúc
    double effectiveOpen = _params.mouthOpen;
    if (_state == FaceState.speaking) {
      double speakFactor;
      if (_volume > 0.04) {
        speakFactor = _volume;
      } else {
        // Nhấp nháy giả lập nhịp nói tự nhiên
        final wave1 = math.sin(_timeSeconds * 14.0);
        final wave2 = math.sin(_timeSeconds * 8.5 + 0.8);
        final cadence = (math.sin(_timeSeconds * 3.2) > -0.2) ? 1.0 : 0.18;
        final raw = (wave1 * 0.45 + wave2 * 0.35 + 0.42) * cadence;
        speakFactor = raw.clamp(0.08, 0.92);
      }
      effectiveOpen = math.max(effectiveOpen, speakFactor * 0.85);
    }

    // 1. Biểu cảm ngạc nhiên: Miệng chữ O tròn
    if (_params.mouthRoundness > 0.5) {
      final double rx = mw2 * 0.42;
      final double ry = mh * (0.65 + 0.55 * effectiveOpen);

      _fillPaint
        ..color = _withOpacity(mainColor, 0.18 * glow)
        ..maskFilter = null;
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        _fillPaint,
      );

      _glowStrokePaint
        ..color = _withOpacity(mainColor, 0.35 * glow)
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.5);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        _glowStrokePaint,
      );

      _strokePaint
        ..color = _withOpacity(mainColor, 0.95 * glow)
        ..strokeWidth = 3.8
        ..maskFilter = null;
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        _strokePaint,
      );

      _coreStrokePaint
        ..color = _withOpacity(coreColor, 0.85 * glow)
        ..strokeWidth = 1.8;
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        _coreStrokePaint,
      );

      canvas.restore();
      return;
    }

    final double skewY = _params.mouthSkew * 8.0;
    final double leftY = -skewY;
    final double rightY = skewY;
    final double curveOffset = _params.mouthCurve * 22.0;

    // 2. Miệng mở (đang nói hoặc đang cười to)
    if (effectiveOpen > 0.08) {
      _path.reset();
      _path.moveTo(-mw2, leftY);
      _path.quadraticBezierTo(0, curveOffset * 0.5, mw2, rightY);
      _path.quadraticBezierTo(
        0,
        curveOffset * 0.3 + mh * effectiveOpen * 1.35,
        -mw2,
        leftY,
      );
      _path.close();

      _fillPaint
        ..color = _withOpacity(mainColor, 0.18 * glow)
        ..maskFilter = null;
      canvas.drawPath(_path, _fillPaint);

      _glowStrokePaint
        ..color = _withOpacity(mainColor, 0.35 * glow)
        ..strokeWidth = 6.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.5);
      canvas.drawPath(_path, _glowStrokePaint);

      _strokePaint
        ..color = _withOpacity(mainColor, 0.95 * glow)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = null;
      canvas.drawPath(_path, _strokePaint);

      // Điểm sáng môi trên
      _altPath.reset();
      _altPath.moveTo(-mw2, leftY);
      _altPath.quadraticBezierTo(0, curveOffset * 0.5, mw2, rightY);
      _coreStrokePaint
        ..color = _withOpacity(coreColor, 0.85 * glow)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(_altPath, _coreStrokePaint);

      canvas.restore();
      return;
    }

    // 3. Miệng khép: Đường nét cong / biểu cảm
    _path.reset();
    if (_params.mouthSkew > 0.35 && _params.mouthRoundness < 0.2) {
      // Dạng lượn sóng bối rối (confused)
      _path.moveTo(-mw2, 4.0);
      _path.cubicTo(-mw2 * 0.4, 16.0, 0, -12.0, mw2, -6.0);
    } else {
      // Đường cong chuẩn
      _path.moveTo(-mw2, leftY);
      _path.quadraticBezierTo(0, curveOffset, mw2, rightY);
    }

    _glowStrokePaint
      ..color = _withOpacity(mainColor, 0.35 * glow)
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.5);
    canvas.drawPath(_path, _glowStrokePaint);

    _strokePaint
      ..color = _withOpacity(mainColor, 0.95 * glow)
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..maskFilter = null;
    canvas.drawPath(_path, _strokePaint);

    _coreStrokePaint
      ..color = _withOpacity(coreColor, 0.85 * glow)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(_path, _coreStrokePaint);

    canvas.restore();
  }

  static Color _withOpacity(Color c, double opacity) {
    final int a = (opacity.clamp(0.0, 1.0) * 255).round();
    return c.withAlpha(a);
  }

  @override
  bool shouldRepaint(covariant _RobotFacePainter oldDelegate) => true;
}
