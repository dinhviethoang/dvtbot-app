import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Các trạng thái biểu cảm của mắt robot botAi
enum RobotEyeState {
  idle, // Nghỉ ngơi: thỉnh thoảng chớp mắt cơ khí, mống mắt đảo nhẹ
  listening, // Đang nghe: mống mắt mở rộng, vòng sáng phản hồi theo âm lượng
  thinking, // Đang suy nghĩ: vòng quét HUD xoay tròn liên tục
  speaking, // Đang nói: mống mắt và vòng sáng nhịp đập theo giọng nói
  error, // Lỗi / Cảnh báo: màu đỏ neon, nhấp nháy báo động
}

/// Widget hiển thị đôi mắt robot phong cách cơ khí / Mecha HUD
/// Tự thiết kế nguyên bản, không sao chép nhân vật có bản quyền.
/// Tối ưu tuyệt đối cho máy cấu hình thấp (Samsung J2 Pro, RAM 1.5GB):
/// - Bọc trong RepaintBoundary để cô lập lớp vẽ
/// - Không dùng blur nặng / ImageFilter
/// - Chỉ dùng duy nhất một AnimationController
class RobotEyes extends StatefulWidget {
  final RobotEyeState state;
  final double
  volume; // Giá trị âm lượng 0.0 -> 1.0 (cho listening và speaking)
  final double width;
  final double height;

  const RobotEyes({
    super.key,
    this.state = RobotEyeState.idle,
    this.volume = 0.0,
    this.width = double.infinity,
    this.height = 240.0,
  });

  @override
  State<RobotEyes> createState() => _RobotEyesState();
}

class _RobotEyesState extends State<RobotEyes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 1 Controller duy nhất điều khiển toàn bộ chu kỳ hoạt ảnh (3.6 giây lặp lại)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size(widget.width, widget.height),
            painter: _RobotEyesPainter(
              state: widget.state,
              progress: _controller.value,
              volume: widget.volume.clamp(0.0, 1.0),
            ),
          );
        },
      ),
    );
  }
}

class _RobotEyesPainter extends CustomPainter {
  final RobotEyeState state;
  final double progress; // 0.0 -> 1.0 theo thời gian
  final double volume;

  _RobotEyesPainter({
    required this.state,
    required this.progress,
    required this.volume,
  });

  // Bảng màu Mecha HUD Cyber
  static const Color colorCyanNeon = Color(0xFF00F0FF);
  static const Color colorCyanCore = Color(0xFF80F8FF);
  static const Color colorCyanDark = Color(0xFF005F73);
  static const Color colorRedNeon = Color(0xFFFF1744);
  static const Color colorRedCore = Color(0xFFFF8A9E);
  static const Color colorRedDark = Color(0xFF7F091F);
  static const Color colorMetalDark = Color(0xFF0D1520);
  static const Color colorMetalFrame = Color(0xFF1F2D3D);
  static const Color colorMetalBevel = Color(0xFF33475B);
  static const Color colorCavity = Color(0xFF060A10);

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    if (width <= 0 || height <= 0) return;

    final double centerX = width / 2;
    final double centerY = height / 2;

    // Kích thước mỗi bên mắt (tỷ lệ chuẩn theo màn hình nhỏ 540x960)
    final double eyeWidth = math.min(width * 0.38, height * 1.1);
    final double eyeHeight = eyeWidth * 0.70;
    final double eyeGap = width * 0.08;

    final double leftEyeCenterX = centerX - (eyeGap / 2) - (eyeWidth / 2);
    final double rightEyeCenterX = centerX + (eyeGap / 2) + (eyeWidth / 2);

    // Tính toán độ chớp mắt (blink)
    // Trong trạng thái idle: chớp mắt tự nhiên mỗi chu kỳ (khoảng 160ms)
    double blinkProgress = 0.0;
    if (state == RobotEyeState.idle) {
      // Chớp ở khoảng progress từ 0.88 đến 0.94
      if (progress >= 0.88 && progress <= 0.94) {
        final double normalized = (progress - 0.88) / 0.06;
        blinkProgress = math.sin(normalized * math.pi); // 0 -> 1 -> 0
      }
    } else if (state == RobotEyeState.error) {
      // Cảnh báo lỗi: chớp nháy nhanh chu kỳ cao
      final double strobe = math.sin(progress * math.pi * 12);
      blinkProgress = strobe > 0.3 ? 0.85 : 0.0;
    }

    // Tính toán độ đảo của mống mắt (iris wandering)
    double wanderX = 0.0;
    double wanderY = 0.0;
    if (state == RobotEyeState.idle) {
      wanderX = math.sin(progress * math.pi * 2) * (eyeWidth * 0.06);
      wanderY = math.cos(progress * math.pi * 2) * (eyeHeight * 0.04);
    }

    // Góc xoay của vòng quét HUD
    double hudRotation = 0.0;
    if (state == RobotEyeState.thinking) {
      // Xoay liên tục khi đang suy nghĩ
      hudRotation = progress * math.pi * 4;
    } else {
      // Xoay chậm nhẹ ở trạng thái khác
      hudRotation = progress * math.pi * 0.5;
    }

    // Chọn dải màu tùy trạng thái
    final bool isError = (state == RobotEyeState.error);
    final Color mainColor = isError ? colorRedNeon : colorCyanNeon;
    final Color coreColor = isError ? colorRedCore : colorCyanCore;
    final Color darkGlowColor = isError ? colorRedDark : colorCyanDark;

    // 1. Vẽ các đường mạch điện tử (circuit lines) nền
    _drawCircuitTraces(
      canvas,
      centerX,
      centerY,
      eyeWidth,
      eyeHeight,
      eyeGap,
      mainColor,
    );

    // 2. Vẽ mắt trái
    _drawSingleEye(
      canvas: canvas,
      eyeCenterX: leftEyeCenterX,
      eyeCenterY: centerY,
      eyeWidth: eyeWidth,
      eyeHeight: eyeHeight,
      isLeft: true,
      blinkProgress: blinkProgress,
      wanderX: wanderX,
      wanderY: wanderY,
      hudRotation: hudRotation,
      mainColor: mainColor,
      coreColor: coreColor,
      darkGlowColor: darkGlowColor,
    );

    // 3. Vẽ mắt phải (đối xứng)
    _drawSingleEye(
      canvas: canvas,
      eyeCenterX: rightEyeCenterX,
      eyeCenterY: centerY,
      eyeWidth: eyeWidth,
      eyeHeight: eyeHeight,
      isLeft: false,
      blinkProgress: blinkProgress,
      wanderX: wanderX,
      wanderY: wanderY,
      hudRotation: -hudRotation, // Xoay ngược chiều cho tính đối xứng mecha
      mainColor: mainColor,
      coreColor: coreColor,
      darkGlowColor: darkGlowColor,
    );
  }

  /// Vẽ một bên mắt hoàn chỉnh: Hốc máy góc cạnh -> Lưới nền -> Mống mắt -> HUD -> Mí máy
  void _drawSingleEye({
    required Canvas canvas,
    required double eyeCenterX,
    required double eyeCenterY,
    required double eyeWidth,
    required double eyeHeight,
    required bool isLeft,
    required double blinkProgress,
    required double wanderX,
    required double wanderY,
    required double hudRotation,
    required Color mainColor,
    required Color coreColor,
    required Color darkGlowColor,
  }) {
    final double halfW = eyeWidth / 2;
    final double halfH = eyeHeight / 2;
    final double dir = isLeft ? 1.0 : -1.0;

    // --- HỐC MẮT GÓC CẠNH (ANGULAR MECHA SOCKET) ---
    // Hình đa giác 6 cạnh vát góc khí động học phong cách robot chiến đấu
    final Path socketPath = Path();
    socketPath.moveTo(
      eyeCenterX - (halfW * 0.95 * dir),
      eyeCenterY - halfH * 0.20,
    ); // Điểm ngoài - trên
    socketPath.lineTo(
      eyeCenterX - (halfW * 0.30 * dir),
      eyeCenterY - halfH * 0.95,
    ); // Điểm giữa đỉnh
    socketPath.lineTo(
      eyeCenterX + (halfW * 0.90 * dir),
      eyeCenterY - halfH * 0.70,
    ); // Điểm trong - trên
    socketPath.lineTo(
      eyeCenterX + (halfW * 0.95 * dir),
      eyeCenterY + halfH * 0.30,
    ); // Điểm trong - dưới
    socketPath.lineTo(
      eyeCenterX - (halfW * 0.20 * dir),
      eyeCenterY + halfH * 0.95,
    ); // Điểm giữa đáy
    socketPath.lineTo(
      eyeCenterX - (halfW * 0.90 * dir),
      eyeCenterY + halfH * 0.50,
    ); // Điểm ngoài - dưới
    socketPath.close();

    // Lớp 1: Khung kim loại viền ngoài dày dặn
    final Paint metalFramePaint =
        Paint()
          ..color = colorMetalFrame
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(socketPath, metalFramePaint);

    // Lớp 2: Khung vát kim loại tối màu bên ngoài (vát 3D)
    final Paint metalBevelPaint =
        Paint()
          ..color = colorMetalBevel
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
    canvas.drawPath(socketPath, metalBevelPaint);

    // Lớp 3: Khoang tối obsidian bên trong
    final Paint cavityPaint =
        Paint()
          ..color = colorCavity
          ..style = PaintingStyle.fill;
    canvas.drawPath(socketPath, cavityPaint);

    // Cắt phạm vi vẽ nội nhãn bên trong hốc mắt
    canvas.save();
    canvas.clipPath(socketPath);

    // --- LƯỚI QUÉT SCANLINE MECHA ---
    final Paint scanlinePaint =
        Paint()
          ..color = darkGlowColor.withOpacity(0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
    for (double y = eyeCenterY - halfH; y <= eyeCenterY + halfH; y += 8.0) {
      canvas.drawLine(
        Offset(eyeCenterX - halfW, y),
        Offset(eyeCenterX + halfW, y),
        scanlinePaint,
      );
    }

    // --- TÍNH TOÁN KÍCH THƯỚC MỐNG MẮT (DYNAMIC IRIS SCALING) ---
    double irisScale = 1.0;
    if (state == RobotEyeState.listening) {
      // Đang nghe: mở to mống mắt và dao động theo âm lượng
      irisScale = 1.15 + (volume * 0.25);
    } else if (state == RobotEyeState.speaking) {
      // Đang nói: nhịp đập sinh động
      final double speechPulse = math.sin(progress * math.pi * 10);
      irisScale = 1.0 + (speechPulse * 0.12) + (volume * 0.20);
    } else if (state == RobotEyeState.thinking) {
      // Đang nghĩ: co nhẹ tạo cảm giác tập trung
      final double thinkPulse = math.sin(progress * math.pi * 3);
      irisScale = 0.92 + (thinkPulse * 0.08);
    }

    final double irisCenterX = eyeCenterX + wanderX;
    final double irisCenterY = eyeCenterY + wanderY;
    final double baseRadius = halfH * 0.52 * irisScale;

    // --- VÒNG QUÉT HUD (HUD SCANNING RING) ---
    _drawHudRings(
      canvas: canvas,
      cx: irisCenterX,
      cy: irisCenterY,
      radius: baseRadius * 1.35,
      rotation: hudRotation,
      color: mainColor,
      isThinking: state == RobotEyeState.thinking,
    );

    // --- MỐNG MẮT PHÁT SÁNG ĐA LỚP (GLOWING IRIS & CORE) ---
    // Vầng hào quang ngoài (không dùng blur, dùng alpha xếp lớp nhẹ)
    final Paint outerGlowPaint =
        Paint()
          ..color = darkGlowColor.withOpacity(0.25)
          ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(irisCenterX, irisCenterY),
      baseRadius * 1.25,
      outerGlowPaint,
    );

    final Paint midGlowPaint =
        Paint()
          ..color = mainColor.withOpacity(0.45)
          ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(irisCenterX, irisCenterY),
      baseRadius * 0.95,
      midGlowPaint,
    );

    // Mống mắt đa giác lục giác cơ khí
    final Path irisHex = Path();
    for (int i = 0; i < 6; i++) {
      final double angle = (i * math.pi / 3) + (isLeft ? 0.0 : math.pi / 6);
      final double hx = irisCenterX + (baseRadius * 0.75 * math.cos(angle));
      final double hy = irisCenterY + (baseRadius * 0.75 * math.sin(angle));
      if (i == 0) {
        irisHex.moveTo(hx, hy);
      } else {
        irisHex.lineTo(hx, hy);
      }
    }
    irisHex.close();

    final Paint irisPaint =
        Paint()
          ..color = mainColor
          ..style = PaintingStyle.fill;
    canvas.drawPath(irisHex, irisPaint);

    // Lõi phát sáng trắng/cyan nóng rực ở tâm (Hot pupil core)
    final Paint corePaint =
        Paint()
          ..color = coreColor
          ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(irisCenterX, irisCenterY),
      baseRadius * 0.38,
      corePaint,
    );

    final Paint whiteHotPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(irisCenterX, irisCenterY),
      baseRadius * 0.18,
      whiteHotPaint,
    );

    // Điểm nhấn công nghệ: thanh quét con ngươi ngang
    final Paint slitPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(irisCenterX - (baseRadius * 0.50), irisCenterY),
      Offset(irisCenterX + (baseRadius * 0.50), irisCenterY),
      slitPaint,
    );

    // --- MÍ MÁY CƠ KHÍ ĐÓNG MỞ (MECHA EYELID SHUTTERS) ---
    if (blinkProgress > 0.0) {
      final double closeOffset = (halfH + 4) * blinkProgress;

      // Mí trên trượt xuống
      final Path topLid =
          Path()
            ..moveTo(eyeCenterX - halfW - 2, eyeCenterY - halfH - 2)
            ..lineTo(eyeCenterX + halfW + 2, eyeCenterY - halfH - 2)
            ..lineTo(eyeCenterX + halfW + 2, eyeCenterY - halfH + closeOffset)
            ..lineTo(eyeCenterX - halfW - 2, eyeCenterY - halfH + closeOffset)
            ..close();

      // Mí dưới trượt lên
      final Path bottomLid =
          Path()
            ..moveTo(eyeCenterX - halfW - 2, eyeCenterY + halfH + 2)
            ..lineTo(eyeCenterX + halfW + 2, eyeCenterY + halfH + 2)
            ..lineTo(eyeCenterX + halfW + 2, eyeCenterY + halfH - closeOffset)
            ..lineTo(eyeCenterX - halfW - 2, eyeCenterY + halfH - closeOffset)
            ..close();

      final Paint lidPaint =
          Paint()
            ..color = colorMetalDark
            ..style = PaintingStyle.fill;

      final Paint lidEdgePaint =
          Paint()
            ..color = mainColor.withOpacity(0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;

      canvas.drawPath(topLid, lidPaint);
      canvas.drawPath(bottomLid, lidPaint);

      // Viền sáng tại mép mí máy
      canvas.drawLine(
        Offset(eyeCenterX - halfW, eyeCenterY - halfH + closeOffset),
        Offset(eyeCenterX + halfW, eyeCenterY - halfH + closeOffset),
        lidEdgePaint,
      );
      canvas.drawLine(
        Offset(eyeCenterX - halfW, eyeCenterY + halfH - closeOffset),
        Offset(eyeCenterX + halfW, eyeCenterY + halfH - closeOffset),
        lidEdgePaint,
      );
    }

    // Kết thúc vùng clip hốc mắt
    canvas.restore();

    // --- VẠCH HIỆU CHUẨN GÓC HUD (CORNER CALIBRATION BRACKETS) ---
    _drawCornerBrackets(
      canvas,
      eyeCenterX,
      eyeCenterY,
      halfW,
      halfH,
      dir,
      mainColor,
    );
  }

  /// Vẽ các vòng quét HUD đồng tâm và cung xoay
  void _drawHudRings({
    required Canvas canvas,
    required double cx,
    required double cy,
    required double radius,
    required double rotation,
    required Color color,
    required bool isThinking,
  }) {
    // Vòng cung đứt đoạn 1 (vòng chính)
    final Rect ringRect = Rect.fromCircle(
      center: Offset(cx, cy),
      radius: radius,
    );
    final Paint arcPaint =
        Paint()
          ..color = color.withOpacity(0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isThinking ? 2.2 : 1.5
          ..strokeCap = StrokeCap.round;

    // Vẽ 4 đoạn cung cách đều nhau
    const double arcLength = math.pi * 0.35;
    for (int i = 0; i < 4; i++) {
      final double startAngle = rotation + (i * math.pi * 0.5);
      canvas.drawArc(ringRect, startAngle, arcLength, false, arcPaint);
    }

    // Vòng mỏng đồng tâm ngoài
    final Paint thinRingPaint =
        Paint()
          ..color = color.withOpacity(0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8;
    canvas.drawCircle(Offset(cx, cy), radius * 1.15, thinRingPaint);

    // Chấm tọa độ HUD
    final Paint tickPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final double a = rotation * 0.5 + (i * math.pi / 4);
      final double tx = cx + (radius * 1.15 * math.cos(a));
      final double ty = cy + (radius * 1.15 * math.sin(a));
      canvas.drawCircle(Offset(tx, ty), 1.2, tickPaint);
    }
  }

  /// Vẽ vạch góc HUD khung ngắm công nghệ
  void _drawCornerBrackets(
    Canvas canvas,
    double cx,
    double cy,
    double halfW,
    double halfH,
    double dir,
    Color color,
  ) {
    final Paint bracketPaint =
        Paint()
          ..color = color.withOpacity(0.40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;

    const double bracketLen = 8.0;
    final double left = cx - halfW - 4;
    final double right = cx + halfW + 4;
    final double top = cy - halfH - 4;
    final double bottom = cy + halfH + 4;

    // Góc trên - ngoài
    canvas.drawLine(
      Offset(left, top + bracketLen),
      Offset(left, top),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left + bracketLen, top),
      bracketPaint,
    );

    // Góc dưới - ngoài
    canvas.drawLine(
      Offset(left, bottom - bracketLen),
      Offset(left, bottom),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left + bracketLen, bottom),
      bracketPaint,
    );

    // Góc trên - trong
    canvas.drawLine(
      Offset(right - bracketLen, top),
      Offset(right, top),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(right, top),
      Offset(right, top + bracketLen),
      bracketPaint,
    );

    // Góc dưới - trong
    canvas.drawLine(
      Offset(right - bracketLen, bottom),
      Offset(right, bottom),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - bracketLen),
      bracketPaint,
    );
  }

  /// Vẽ đường mạch điện tử vi tính (Cyber Circuit Traces) nối hai bên thái dương
  void _drawCircuitTraces(
    Canvas canvas,
    double cx,
    double cy,
    double eyeW,
    double eyeH,
    double gap,
    Color color,
  ) {
    final Paint tracePaint =
        Paint()
          ..color = color.withOpacity(0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    final Paint nodePaint =
        Paint()
          ..color = color.withOpacity(0.45)
          ..style = PaintingStyle.fill;

    // Cầu nối trung tâm giữa hai mắt
    final double bridgeY = cy - eyeH * 0.40;
    canvas.drawLine(
      Offset(cx - (gap * 0.35), bridgeY),
      Offset(cx + (gap * 0.35), bridgeY),
      tracePaint,
    );
    canvas.drawCircle(Offset(cx - (gap * 0.35), bridgeY), 2.0, nodePaint);
    canvas.drawCircle(Offset(cx + (gap * 0.35), bridgeY), 2.0, nodePaint);
    canvas.drawCircle(Offset(cx, bridgeY), 2.5, nodePaint);

    // Đường mạch thái dương trái
    final double leftOutX = cx - (gap / 2) - eyeW;
    final Path leftTrace =
        Path()
          ..moveTo(leftOutX + 6, cy - eyeH * 0.20)
          ..lineTo(leftOutX - 16, cy - eyeH * 0.20)
          ..lineTo(leftOutX - 28, cy - eyeH * 0.45)
          ..lineTo(leftOutX - 42, cy - eyeH * 0.45);
    canvas.drawPath(leftTrace, tracePaint);
    canvas.drawCircle(Offset(leftOutX - 42, cy - eyeH * 0.45), 2.0, nodePaint);

    // Đường mạch thái dương phải
    final double rightOutX = cx + (gap / 2) + eyeW;
    final Path rightTrace =
        Path()
          ..moveTo(rightOutX - 6, cy - eyeH * 0.20)
          ..lineTo(rightOutX + 16, cy - eyeH * 0.20)
          ..lineTo(rightOutX + 28, cy - eyeH * 0.45)
          ..lineTo(rightOutX + 42, cy - eyeH * 0.45);
    canvas.drawPath(rightTrace, tracePaint);
    canvas.drawCircle(Offset(rightOutX + 42, cy - eyeH * 0.45), 2.0, nodePaint);
  }

  @override
  bool shouldRepaint(covariant _RobotEyesPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.state != state ||
        oldDelegate.volume != volume;
  }
}
