import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_assistant/models/conversation.dart';
import 'package:ai_assistant/models/message.dart';
import 'package:ai_assistant/models/xiaozhi_config.dart';
import 'package:ai_assistant/providers/conversation_provider.dart';
import 'package:ai_assistant/providers/config_provider.dart';
import 'package:ai_assistant/services/xiaozhi_service.dart';
import 'package:ai_assistant/services/xiaozhi_ota_service.dart';
import 'package:ai_assistant/utils/app_theme.dart';
import 'package:ai_assistant/utils/device_util.dart';
import 'package:ai_assistant/utils/emotion_detector.dart';
import 'package:ai_assistant/utils/audio_util.dart';
import 'package:ai_assistant/utils/app_log.dart';
import 'package:ai_assistant/screens/log_screen.dart';
import 'package:ai_assistant/screens/chat_screen.dart';
import 'package:ai_assistant/widgets/robot_face.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ai_assistant/assistant_v2/assistant_mode.dart';
import 'package:ai_assistant/assistant_v2/assistant_v2_bridge.dart';
import 'package:ai_assistant/services/assistant_action_executor.dart';

/// Máy trạng thái vòng đời phiên gọi thoại
enum SessionState {
  activating,
  connecting,
  standby,
  wakeDetected,
  listening,
  thinking,
  speaking,
  executing,
  error,
}

/// Màn hình gọi thoại botAi với avatar robot mạch điện tử
/// Tối ưu đặc biệt cho Samsung J2 Pro (540x960, RAM 1.5GB) và các dòng máy Android mới
class VoiceCallScreen extends StatefulWidget {
  final Conversation conversation;
  final XiaozhiConfig xiaozhiConfig;

  const VoiceCallScreen({
    super.key,
    required this.conversation,
    required this.xiaozhiConfig,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with SingleTickerProviderStateMixin {
  XiaozhiService? _xiaozhiService;
  final XiaozhiOtaService _otaService = XiaozhiOtaService();
  OtaCancellationToken? _otaCancelToken;
  late XiaozhiConfig _currentConfig;

  // Trạng thái kích hoạt OTA
  bool _showActivationOverlay = false;
  bool _isOtaConnecting = false;
  String? _activationCode;
  String _otaStatus = 'Đang kết nối máy chủ...';
  String? _otaError;

  bool _isConnected = false;
  bool _isSpeaking = false; // Micro máy khách đang thu âm
  bool _isRobotSpeaking = false; // Robot đang phát giọng TTS
  bool _isThinking = false; // Robot đang xử lý/suy nghĩ
  bool _hasError = false; // Có lỗi kết nối / mic
  String _statusText = 'Đang kết nối...';
  String _latestSubtitle = ''; // Phụ đề câu nói gần nhất
  Timer? _callTimer;
  Duration _callDuration = Duration.zero;
  bool _serverReady = false;
  Timer? _disconnectDebounceTimer;

  // Cảm xúc robot (mặc định neutral khi rảnh rỗi) và đếm giờ về neutral
  FaceEmotion _currentEmotion = FaceEmotion.neutral;
  Timer? _idleEmotionTimer;
  String? _lastDetectedSentence;

  // Thanh điều khiển nhỏ mờ ở mép dưới
  bool _showControls = false;
  Timer? _controlsTimer;

  late AnimationController _animationController;
  final List<double> _audioLevels = List.filled(24, 0.05);
  Timer? _audioVisualizerTimer;

  // Máy trạng thái phiên
  SessionState _sessionState = SessionState.activating;
  StreamSubscription<double>? _amplitudeSubscription;
  Timer? _silenceTimer;
  Timer? _longPress2sTimer;
  bool _longPressTriggered = false;
  bool _isWakingUp = false;

  final AssistantV2Bridge _v2Bridge = AssistantV2Bridge();
  StreamSubscription<AssistantNativeEvent>? _nativeEventsSubscription;

  // Lưu lời thoại vào đoạn chat (tránh trùng lặp)
  String? _lastSavedUserSentence;
  String? _lastSavedAssistantSentence;

  @override
  void initState() {
    super.initState();
    _currentConfig = widget.xiaozhiConfig;

    // Bật chế độ toàn màn hình ẩn hoàn toàn thanh trạng thái & điều hướng
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Lắng nghe sự kiện từ Native Wake Word & Accessibility Service
    _nativeEventsSubscription = _v2Bridge.events.listen((event) {
      _handleNativeEvent(event);
    });
    _initWakeServiceSafely();

    // Bắt đầu quy trình kích hoạt OTA và kết nối
    _startActivationFlow();
    _startAudioVisualizer();
  }

  Future<void> _initWakeServiceSafely() async {
    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }
      if (status.isGranted) {
        final started = await _v2Bridge.startWakeService();
        if (!started && mounted) {
          AppLog.add('[NativeBridge] Khong the khoi dong WakeService');
        }
      } else {
        AppLog.add('[NativeBridge] Quyen RECORD_AUDIO bi tu choi');
        if (mounted) {
          setState(() {
            _statusText = 'Cần cấp quyền microphone';
          });
        }
      }
    } catch (e) {
      AppLog.add('[NativeBridge] Loi khoi dong wake service: $e');
    }
  }

  void _handleNativeEvent(AssistantNativeEvent event) {
    AppLog.add('[NativeBridge] Event: ${event.mode}, lý do: ${event.reason}');
    if (event.mode == AssistantMode.wakeDetected) {
      HapticFeedback.mediumImpact();
      _wakeUp('Nhận diện câu gọi “TinGTinG ơi”');
    } else if (event.mode == AssistantMode.standby) {
      if (_sessionState != SessionState.standby) {
        _goToSleep(reason: 'Native chuyển sang standby');
      }
    } else if (event.mode == AssistantMode.error) {
      if (mounted) {
        setState(() {
          _statusText = event.reason ?? 'Lỗi nhận diện âm thanh';
        });
      }
    }
  }

  /// Khởi chạy quy trình kích hoạt OTA
  Future<void> _startActivationFlow() async {
    _otaCancelToken?.cancel();
    final cancelToken = OtaCancellationToken();
    _otaCancelToken = cancelToken;

    setState(() {
      _showActivationOverlay = true;
      _isOtaConnecting = true;
      _activationCode = null;
      _otaError = null;
      _otaStatus = 'Đang kết nối máy chủ...';
    });

    try {
      final mac =
          DeviceUtil.isValidMac(_currentConfig.macAddress)
              ? _currentConfig.macAddress
              : await DeviceUtil.getDeviceMac();
      final clientId = await DeviceUtil.getClientId();

      if (_currentConfig.macAddress != mac) {
        _currentConfig = _currentConfig.copyWith(macAddress: mac);
      }

      final result = await _otaService.ensureActivated(
        otaUrl: _currentConfig.otaUrl,
        mac: mac,
        clientId: clientId,
        onActivationCode: (code) {
          if (!mounted || cancelToken.isCancelled) return;
          setState(() {
            _activationCode = code;
            _isOtaConnecting = false;
            _otaStatus = 'Đang chờ kích hoạt...';
          });
        },
        onStatusChange: (status) {
          if (!mounted || cancelToken.isCancelled) return;
          setState(() {
            _otaStatus = status;
          });
        },
        cancelToken: cancelToken,
      );

      if (!mounted || cancelToken.isCancelled) return;

      // Cập nhật cấu hình lưu trữ
      final updatedConfig = _currentConfig.copyWith(
        websocketUrl: result.websocketUrl,
        token: result.websocketToken,
        macAddress: mac,
      );
      _currentConfig = updatedConfig;

      await Provider.of<ConfigProvider>(
        context,
        listen: false,
      ).updateXiaozhiConfig(updatedConfig);

      if (!mounted || cancelToken.isCancelled) return;

      setState(() {
        _showActivationOverlay = false;
        _isOtaConnecting = false;
        _otaError = null;
        _sessionState = SessionState.connecting;
      });

      // Huỷ đăng ký listener cũ nếu có trước khi tạo service mới
      _xiaozhiService?.removeListener(_handleServiceEvent);
      _xiaozhiService?.emotionNotifier.removeListener(_handleEmotionChange);

      // Tạo và kết nối XiaozhiService với websocket url & token từ OTA
      _xiaozhiService = XiaozhiService(
        websocketUrl: updatedConfig.websocketUrl,
        macAddress: updatedConfig.macAddress,
        clientId: clientId,
        token: updatedConfig.token,
        sessionId: widget.conversation.id,
      );

      _xiaozhiService!.setMessageListener(_handleServerMessage);
      _xiaozhiService!.addListener(_handleServiceEvent);
      _xiaozhiService!.emotionNotifier.addListener(_handleEmotionChange);

      // Lấy cảm xúc ban đầu nếu đã có (mặc định neutral)
      _currentEmotion = _resolveEmotion(_xiaozhiService!.emotionNotifier.value);

      _connectToVoiceService();
    } catch (e) {
      if (!mounted || cancelToken.isCancelled) return;
      print('Lỗi kích hoạt OTA VoiceCallScreen: $e');
      setState(() {
        _isOtaConnecting = false;
        _otaError = e.toString().replaceFirst('Exception: ', '');
        _sessionState = SessionState.error;
      });
    }
  }

  /// Ánh xạ cảm xúc: server gửi "neutral" thì hiển thị neutral, không ép mặt cười mặc định
  FaceEmotion _resolveEmotion(String? raw) {
    return RobotFace.faceEmotionFromServer(raw);
  }

  /// P0.1 - Emotion Pipeline duy nhất cho toàn bộ màn hình
  void _applyEmotion(FaceEmotion emotion, {required String source}) {
    if (!mounted) return;
    AppLog.add(
      '[EMOTION] state=${_sessionState.name} emotion=${emotion.name} source=$source',
    );
    if (_currentEmotion != emotion) {
      setState(() {
        _currentEmotion = emotion;
      });
    }
    // Nếu có cảm xúc đặc biệt thì khởi động đếm giờ về neutral sau 6s
    if (emotion != FaceEmotion.neutral &&
        emotion != FaceEmotion.sleepy &&
        _sessionState != SessionState.speaking &&
        _sessionState != SessionState.thinking &&
        _sessionState != SessionState.standby) {
      _startIdleEmotionTimer();
    }
  }

  void _handleEmotionChange() {
    if (!mounted) return;
    final rawEmotion = _xiaozhiService?.emotionNotifier.value;
    final parsed = _resolveEmotion(rawEmotion);
    _applyEmotion(parsed, source: 'emotionNotifier');
  }

  void _startIdleEmotionTimer() {
    _idleEmotionTimer?.cancel();
    _idleEmotionTimer = Timer(const Duration(seconds: 6), () {
      if (mounted &&
          _sessionState != SessionState.speaking &&
          _sessionState != SessionState.thinking &&
          _sessionState != SessionState.standby) {
        _applyEmotion(FaceEmotion.neutral, source: 'idle_timeout');
      }
    });
  }

  /// Xử lý nhận diện cảm xúc theo từng câu nói của robot theo quy tắc ưu tiên:
  /// 1. Emotion từ server
  /// 2. Emotion từ nội dung câu nói (EmotionDetector)
  /// 3. Giữ neutral
  void _onRobotSentence(String sentence) {
    final trimmed = sentence.trim();
    if (trimmed.isEmpty || trimmed == _lastDetectedSentence) return;
    _lastDetectedSentence = trimmed;

    final rawEmotion = _xiaozhiService?.emotionNotifier.value;
    FaceEmotion targetEmotion = FaceEmotion.neutral;
    String source = 'neutral';

    if (rawEmotion != null &&
        rawEmotion.isNotEmpty &&
        rawEmotion.toLowerCase() != 'neutral') {
      targetEmotion = _resolveEmotion(rawEmotion);
      source = 'server';
    } else {
      final detected = detectEmotionFromText(trimmed);
      if (detected != null) {
        targetEmotion = detected;
        source = 'text';
      } else {
        targetEmotion = FaceEmotion.neutral;
        source = 'fallback';
      }
    }

    _applyEmotion(targetEmotion, source: source);
  }

  void _saveUserMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed == _lastSavedUserSentence) return;
    _lastSavedUserSentence = trimmed;
    _lastSavedAssistantSentence = null;
    AppLog.add('[Chat] Luu user: $trimmed');
    Provider.of<ConversationProvider>(context, listen: false).addMessage(
      conversationId: widget.conversation.id,
      role: MessageRole.user,
      content: trimmed,
    );
  }

  void _saveAssistantMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed == _lastSavedAssistantSentence) return;
    _lastSavedAssistantSentence = trimmed;
    _lastSavedUserSentence = null;
    AppLog.add('[Chat] Luu assistant: $trimmed');
    Provider.of<ConversationProvider>(context, listen: false).addMessage(
      conversationId: widget.conversation.id,
      role: MessageRole.assistant,
      content: trimmed,
    );
  }

  Future<void> _goToSleep({String reason = 'Server ket thuc phien'}) async {
    if (!mounted || _sessionState == SessionState.standby) return;

    AppLog.add('[Phien] Chuyen sang STANDBY ($reason)');

    _silenceTimer?.cancel();
    _silenceTimer = null;
    _disconnectDebounceTimer?.cancel();
    _disconnectDebounceTimer = null;
    _idleEmotionTimer?.cancel();
    _idleEmotionTimer = null;

    _isSpeaking = false;
    _isRobotSpeaking = false;
    _isThinking = false;
    _serverReady = false;

    // Ngừng ghi âm micro phía Flutter trước khi bàn giao cho Native
    await _xiaozhiService?.stopListeningCall();

    // Thông báo cho Native Foreground Service mở lại AudioRecord để bắt từ khoá "TinGTinG ơi"
    await _v2Bridge.endConversation();
    AppLog.add('[AUDIO] owner=standby_wake');

    if (mounted) {
      setState(() {
        _sessionState = SessionState.standby;
        _statusText = 'Chờ “TinGTinG ơi”...';
      });
      _applyEmotion(FaceEmotion.sleepy, source: 'state_standby');
    }
  }

  Future<void> _startLocalWakeMonitoring() async {
    // Không dùng amplitude thô; việc lắng nghe được xử lý hoàn toàn bởi Native WakeWordForegroundService
  }

  Future<void> _stopLocalWakeMonitoring() async {
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
  }

  Future<void> _wakeUp(String reason) async {
    if (_isWakingUp) return;
    _isWakingUp = true;

    AppLog.add('[DanhThuc] Bat dau quy trinh danh thuc ($reason)');
    await _v2Bridge.beginConversation();
    AppLog.add('[AUDIO] owner=conversation');

    if (mounted) {
      setState(() {
        _sessionState = SessionState.wakeDetected;
        _statusText = 'Đã nhận diện “TinGTinG ơi”';
        _hasError = false;
      });
      _applyEmotion(FaceEmotion.surprised, source: 'state_wakeDetected');
    }

    try {
      if (_xiaozhiService == null) {
        throw Exception('Chưa khởi tạo dịch vụ');
      }

      await _xiaozhiService!.switchToVoiceCallMode();

      // Nếu socket chưa kết nối thì kết nối và chờ hello
      if (!_xiaozhiService!.isConnected) {
        _xiaozhiService!.clearSessionId();
        await _xiaozhiService!.connect();
        AppLog.add('[DanhThuc] Cho hello tu server (toi da 8s)...');
        final sessionId = await _xiaozhiService!.waitForHello(
          timeout: const Duration(seconds: 8),
        );
        if (sessionId == null) {
          throw Exception('Hết 8s chờ hello từ server');
        }
        AppLog.add('[DanhThuc] Nhan hello thanh cong, session_id: $sessionId');
      }

      if (!mounted) {
        _isWakingUp = false;
        return;
      }

      _isSpeaking = true;
      _isRobotSpeaking = false;
      _isThinking = false;
      _serverReady = true;
      _hasError = false;

      // Gửi listen start (mode auto) và bắt đầu thu âm từ micro
      await _xiaozhiService!.startListeningCall();

      if (mounted) {
        setState(() {
          _sessionState = SessionState.listening;
          _statusText = 'Đang lắng nghe...';
        });
        _applyEmotion(FaceEmotion.neutral, source: 'state_listening');
      }

      _resetSilenceTimer();
    } catch (e) {
      AppLog.add('[DanhThuc] Loi danh thuc: $e');
      if (mounted) {
        _showCustomSnackbar(
          message: 'Lỗi đánh thức: $e',
          icon: Icons.error_outline,
          iconColor: AppTheme.errorColor,
        );
      }
      _isWakingUp = false;
      await _goToSleep(reason: 'Lỗi đánh thức: $e');
      return;
    }

    _isWakingUp = false;
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 20), () {
      if (mounted && _sessionState == SessionState.listening) {
        AppLog.add('[Phien] 20 giay khong co ai noi -> Chuyen sang SLEEPING');
        _goToSleep(reason: '20s không có âm thanh');
      }
    });
  }

  void _handlePointerDown() {
    _longPressTriggered = false;
    _longPress2sTimer?.cancel();
    _longPress2sTimer = Timer(const Duration(seconds: 2), () {
      _longPressTriggered = true;
      HapticFeedback.heavyImpact();
      AppLog.add('[GiaoDien] Nhan giu 2s -> Mo man hinh Nhat ky');
      _openLogScreen();
    });
  }

  void _handlePointerUpOrCancel() {
    _longPress2sTimer?.cancel();
    _longPress2sTimer = null;
  }

  void _handleFaceTap() {
    if (_longPressTriggered) {
      _longPressTriggered = false;
      return;
    }
    if (_sessionState == SessionState.standby) {
      AppLog.add('[DanhThuc] Cham vao khuon mat de danh thuc');
      _wakeUp('Chạm màn hình');
    } else {
      _toggleControls();
    }
  }

  void _openLogScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LogScreen()),
    );
  }

  void _handleServerMessage(dynamic message) {
    if (!mounted) return;
    if (message is Map<String, dynamic>) {
      final String type = message['type'] ?? '';

      // Cập nhật cảm xúc nếu tin nhắn có chứa trường 'emotion'
      final dynamic emotion = message['emotion'];
      if (emotion is String && emotion.isNotEmpty) {
        _applyEmotion(_resolveEmotion(emotion), source: 'server');
      }

      if (type == 'goodbye') {
        AppLog.add('[Phien] Nhan tin nhan goodbye tu server');
        _goToSleep(reason: 'Server gửi goodbye');
        return;
      }

      if (type == 'hello') {
        _disconnectDebounceTimer?.cancel();
        _disconnectDebounceTimer = null;
        setState(() {
          _serverReady = true;
          _isConnected = true;
          _hasError = false;
          _statusText = 'Đã kết nối máy chủ';
        });

        // Tự động bắt đầu thu âm sau khi máy chủ sẵn sàng (đã có session_id)
        if (!_isSpeaking && _sessionState != SessionState.standby) {
          _startSpeaking();
        }
      } else if (type == 'tts') {
        final String state = message['state'] ?? '';
        final String text = message['text'] ?? '';
        if (state == 'sentence_start') {
          _idleEmotionTimer?.cancel();
          _silenceTimer?.cancel();
          if (text.isNotEmpty) {
            _onRobotSentence(text);
            _saveAssistantMessage(text);
          }
          setState(() {
            _isRobotSpeaking = true;
            _isThinking = false;
            _sessionState = SessionState.speaking;
            _statusText = 'botAi đang nói...';
            if (text.isNotEmpty) {
              _latestSubtitle = 'botAi: $text';
            }
          });
        } else if (state == 'sentence_end' || state == 'stop') {
          if (_sessionState != SessionState.standby) {
            setState(() {
              _isRobotSpeaking = false;
              _sessionState = SessionState.listening;
              if (_isSpeaking) {
                _statusText = 'Đang lắng nghe...';
              } else {
                _statusText = 'Sẵn sàng';
              }
            });
          }
          // Khi robot nói xong và về idle qua 6 giây thì trả về neutral
          _startIdleEmotionTimer();

          // Khi tts 'stop': đảm bảo app đang ở trạng thái lắng nghe và reset timer 20s
          if (state == 'stop' && _sessionState != SessionState.standby) {
            if (_isSpeaking) {
              _xiaozhiService?.resumeListeningCall();
            } else {
              _startSpeaking();
            }
            _resetSilenceTimer();
          }
        }
      } else if (type == 'stt') {
        _lastDetectedSentence = null;
        final String text = message['text'] ?? '';
        if (text.isNotEmpty) {
          AppLog.add('[VOICE] stt_transcript_received: $text');
          _saveUserMessage(text);
          _idleEmotionTimer?.cancel();
          _silenceTimer?.cancel();
          setState(() {
            _latestSubtitle = 'Bạn: $text';
            _isThinking = true;
            _sessionState = SessionState.thinking;
            _statusText = 'Đang suy nghĩ...';
          });

          // Kiểm tra câu lệnh kết thúc hội thoại
          final lower = text.toLowerCase();
          if (lower.contains('tạm biệt') ||
              lower.contains('ngủ đi') ||
              lower.contains('dừng lại')) {
            Future.delayed(const Duration(milliseconds: 1000), () {
              _goToSleep(reason: 'Người dùng chào tạm biệt / bảo ngủ đi');
            });
            return;
          }

          // P0.2 & P0.3: Điều phối lệnh thoại qua Action Dispatcher bất đồng bộ
          _dispatchVoiceAction(text);
        }
      } else if (type == 'llm') {
        _lastDetectedSentence = null;
        _idleEmotionTimer?.cancel();
        _silenceTimer?.cancel();
        setState(() {
          _isThinking = true;
          _sessionState = SessionState.thinking;
          _statusText = 'Đang xử lý...';
        });
      }
    }
  }

  /// P0.2 & P0.3 - Xử lý lệnh thoại qua Action Dispatcher bất đồng bộ
  Future<void> _dispatchVoiceAction(String text) async {
    final result = await AssistantActionExecutor.dispatchCommand(text);
    if (result != null) {
      if (result.success) {
        // Hủy bỏ phản hồi từ server AI để tránh câu trả lời mâu thuẫn
        await _xiaozhiService?.sendAbortMessage();
        AppLog.add('[AI] assistant_reply_suppressed');
        AppLog.add('[SESSION] active_after_action=true');

        _saveAssistantMessage(result.message);
        if (mounted) {
          setState(() {
            _latestSubtitle = 'botAi: ${result.message}';
            _isThinking = false;
            _isRobotSpeaking = false;
            _sessionState = SessionState.listening;
            _statusText = 'Đang lắng nghe...';
          });
          _applyEmotion(FaceEmotion.happy, source: 'action_success');
        }

        // Duy trì phiên làm việc, tự động mở lại ghi âm và reset timer im lặng
        _resetSilenceTimer();
        _xiaozhiService?.resumeListeningCall();
      } else {
        AppLog.add('[ACTION] dispatch_failed: ${result.message}');
        if (mounted) {
          setState(() {
            _latestSubtitle = 'botAi: ${result.message}';
            _isThinking = false;
            _sessionState = SessionState.listening;
            _statusText = 'Đang lắng nghe...';
          });
          _applyEmotion(FaceEmotion.confused, source: 'action_failed');
        }
      }
    }
  }

  void _handleServiceEvent(XiaozhiServiceEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case XiaozhiServiceEventType.connected:
        _disconnectDebounceTimer?.cancel();
        _disconnectDebounceTimer = null;
        break;

      case XiaozhiServiceEventType.userMessage:
        _lastDetectedSentence = null;
        _idleEmotionTimer?.cancel();
        setState(() {
          if (event.data is String && (event.data as String).isNotEmpty) {
            _latestSubtitle = 'Bạn: ${event.data}';
          }
          _isThinking = true;
          _statusText = 'Đang suy nghĩ...';
        });
        break;

      case XiaozhiServiceEventType.textMessage:
        _idleEmotionTimer?.cancel();
        final rawText = (event.data is String) ? (event.data as String) : '';
        if (rawText.startsWith('表情:')) {
          break;
        }
        if (rawText.isNotEmpty) {
          _onRobotSentence(rawText);
        }
        setState(() {
          if (rawText.isNotEmpty) {
            _latestSubtitle = 'botAi: $rawText';
          }
          _isRobotSpeaking = true;
          _isThinking = false;
          _statusText = 'botAi đang nói...';
        });
        break;

      case XiaozhiServiceEventType.error:
        setState(() {
          _hasError = true;
          _statusText = 'Lỗi kết nối';
        });
        break;

      case XiaozhiServiceEventType.disconnected:
        AppLog.add('[KetNoi] Event disconnected');
        if (_sessionState != SessionState.standby &&
            _sessionState != SessionState.activating) {
          _goToSleep(reason: 'Mất kết nối server');
        }
        break;

      default:
        break;
    }
  }

  @override
  void dispose() {
    // Khôi phục lại chế độ màn hình thông thường
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    _nativeEventsSubscription?.cancel();
    _v2Bridge.stopWakeService();
    _otaCancelToken?.cancel();
    _idleEmotionTimer?.cancel();
    _controlsTimer?.cancel();
    _disconnectDebounceTimer?.cancel();
    _silenceTimer?.cancel();
    _longPress2sTimer?.cancel();
    _stopLocalWakeMonitoring();

    _xiaozhiService?.removeListener(_handleServiceEvent);
    _xiaozhiService?.emotionNotifier.removeListener(_handleEmotionChange);
    _callTimer?.cancel();
    _audioVisualizerTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _connectToVoiceService() async {
    if (_xiaozhiService == null) return;

    _startCallTimer();

    // Ghi nhận tin nhắn vào lịch sử trò chuyện
    Provider.of<ConversationProvider>(context, listen: false).addMessage(
      conversationId: widget.conversation.id,
      role: MessageRole.assistant,
      content: 'Cuộc gọi thoại đã bắt đầu',
    );

    _wakeUp('Khởi động cuộc gọi thoại');
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration = Duration(seconds: timer.tick);
        });
      }
    });
  }

  void _startAudioVisualizer() {
    _audioVisualizerTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (_isConnected && mounted) {
        setState(() {
          for (int i = 0; i < _audioLevels.length - 1; i++) {
            _audioLevels[i] = _audioLevels[i + 1];
          }

          if (_isRobotSpeaking) {
            // Nhịp theo giọng robot đang nói
            _audioLevels[_audioLevels.length - 1] =
                0.15 + (0.75 * (0.5 + 0.5 * _animationController.value));
          } else if (_isSpeaking) {
            // Nhịp theo micro người dùng
            _audioLevels[_audioLevels.length - 1] =
                0.10 + (0.60 * (0.5 + 0.5 * _animationController.value));
          } else {
            _audioLevels[_audioLevels.length - 1] = 0.05;
          }
        });
      }
    });
  }

  // Bắt đầu thu âm micro
  void _startSpeaking() {
    if (_sessionState == SessionState.standby) {
      _wakeUp('Bật micro');
      return;
    }

    if (!_isSpeaking) {
      setState(() {
        _isSpeaking = true;
        _sessionState = SessionState.listening;
        if (!_isRobotSpeaking && !_isThinking) {
          _statusText = 'Đang lắng nghe...';
        }
      });

      try {
        _xiaozhiService
            ?.startListeningCall()
            .then((_) {
              _resetSilenceTimer();
            })
            .catchError((e) {
              if (mounted) {
                setState(() {
                  _isSpeaking = false;
                  _hasError = true;
                });
                _showCustomSnackbar(
                  message: 'Không thể mở micro: $e',
                  icon: Icons.error_outline,
                  iconColor: AppTheme.errorColor,
                );
              }
            });
      } catch (e) {
        setState(() {
          _isSpeaking = false;
          _hasError = true;
        });
        if (mounted) {
          _showCustomSnackbar(
            message: 'Không thể mở micro: $e',
            icon: Icons.error_outline,
            iconColor: AppTheme.errorColor,
          );
        }
      }
    }
  }

  // Gửi lệnh ngắt lời robot
  void _sendAbortMessage() {
    _lastDetectedSentence = null;
    _xiaozhiService?.sendAbortMessage();
    setState(() {
      _isRobotSpeaking = false;
      _isThinking = false;
      if (_sessionState != SessionState.standby) {
        _sessionState = SessionState.listening;
        _statusText = 'Đang lắng nghe...';
      }
    });
    _startIdleEmotionTimer();
    _resetSilenceTimer();

    if (mounted) {
      _showCustomSnackbar(
        message: 'Đã gửi tín hiệu ngắt lời',
        icon: Icons.pan_tool_rounded,
        iconColor: Colors.orangeAccent,
      );
    }
  }

  void _handleBigMicButton() async {
    _resetControlsTimer();
    AppLog.add('[NutMic] Nguoi dung bam nut MIC lon');

    // Neu dang standby thi danh thuc
    if (_sessionState == SessionState.standby) {
      _wakeUp('Nút MIC lớn');
      return;
    }

    // Neu robot dang noi, ngat loi va bat dau nghe ngay
    if (_isRobotSpeaking) {
      AppLog.add('[NutMic] Robot dang noi, ngat loi va bat dau nghe ngay');
      _sendAbortMessage();
      await Future.delayed(const Duration(milliseconds: 150));
      _startSpeaking();
      return;
    }

    // Neu dang thu am/lang nghe, bam lan nua de dung
    if (_isSpeaking && _sessionState == SessionState.listening) {
      AppLog.add('[NutMic] Dang nghe, bam de dung thu am');
      _silenceTimer?.cancel();
      await _xiaozhiService?.stopListeningCall();
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _statusText = 'Sẵn sàng';
        });
      }
      return;
    }

    // Neu dang ranh, bat dau nghe ngay
    _startSpeaking();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// Xác định trạng thái thật của khuôn mặt robot từ máy trạng thái
  FaceState _resolveFaceState() {
    if (_showActivationOverlay) {
      if (_otaError != null) {
        return FaceState.error;
      }
      return FaceState.connecting;
    }
    if (_hasError && _sessionState != SessionState.standby) {
      return FaceState.error;
    }
    switch (_sessionState) {
      case SessionState.activating:
        return (_otaError != null) ? FaceState.error : FaceState.connecting;
      case SessionState.connecting:
        return FaceState.connecting;
      case SessionState.standby:
        return FaceState.standby;
      case SessionState.wakeDetected:
        return FaceState.wakeDetected;
      case SessionState.listening:
        return FaceState.listening;
      case SessionState.thinking:
        return FaceState.thinking;
      case SessionState.speaking:
        return FaceState.speaking;
      case SessionState.executing:
        return FaceState.executing;
      case SessionState.error:
        return FaceState.error;
    }
  }

  void _toggleControls() {
    if (_showControls) {
      setState(() {
        _showControls = false;
      });
      _controlsTimer?.cancel();
    } else {
      setState(() {
        _showControls = true;
      });
      _resetControlsTimer();
    }
  }

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _switchToChat() {
    _otaCancelToken?.cancel();
    _xiaozhiService?.stopPlayback();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(conversation: widget.conversation),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final faceState = _resolveFaceState();
    final double currentVolume =
        _audioLevels.isNotEmpty ? _audioLevels.last : 0.0;
    final double faceVolume =
        (_sessionState == SessionState.standby) ? 0.0 : currentVolume;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // 1. Thanh tiêu đề trên cùng: Back, botAi, trạng thái, âm thanh, ngắt lời, nhật ký
                _buildTopHeader(),

                // 2. Chỉ hiển thị hai mắt và miệng robot phát sáng neon-blue trên nền đen tuyệt đối
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => _handlePointerDown(),
                      onTapUp: (_) => _handlePointerUpOrCancel(),
                      onTapCancel: () => _handlePointerUpOrCancel(),
                      onTap: _handleFaceTap,
                      child: RobotFace(
                        state: faceState,
                        emotion: _currentEmotion,
                        volume: faceVolume,
                        color: const Color(0xFF00F0FF),
                      ),
                    ),
                  ),
                ),

                // 3. Sóng âm cyan (Waveform)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 6.0,
                  ),
                  child: _buildAudioWaveform(),
                ),

                // 4. Thanh điều khiển dưới cùng: Nhập văn bản, Microphone, Kết thúc
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 16),
                  child: _buildBottomControls(),
                ),
              ],
            ),

            // Lớp phủ kích hoạt OTA (hiển thị mã 6 số) và lớp phủ lỗi khi cần
            if (_showActivationOverlay) _buildActivationOverlay(),

            // Debug overlay: Hiển thị nhỏ FaceState / FaceEmotion trong build Debug, tự động loại khỏi Release
            if (kDebugMode)
              Positioned(
                top: 52,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF00F0FF).withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    '${faceState.name} / ${_currentEmotion.name}',
                    style: const TextStyle(
                      color: Color(0xFF00F0FF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Thanh tiêu đề phía trên: Back, tên botAi, trạng thái kết nối, điều khiển âm thanh
  Widget _buildTopHeader() {
    final isMuted = _xiaozhiService?.isMuted ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          // Nút quay lại bo tròn
          _buildHeaderIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            color: Colors.white70,
            tooltip: 'Quay lại',
            onPressed: () {
              _otaCancelToken?.cancel();
              _xiaozhiService?.stopPlayback();
              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 12),

          // Tên ứng dụng botAi & chấm trạng thái hoạt động
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'botAi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            _hasError
                                ? AppTheme.errorColor
                                : (_sessionState == SessionState.standby
                                    ? Colors.grey
                                    : (_isConnected
                                        ? const Color(0xFF00E676)
                                        : Colors.orangeAccent)),
                        boxShadow: [
                          BoxShadow(
                            color: (_hasError
                                    ? AppTheme.errorColor
                                    : (_isConnected
                                        ? const Color(0xFF00E676)
                                        : Colors.orangeAccent))
                                .withOpacity(0.6),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _statusText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Nút ngắt lời robot (nổi bật khi robot đang nói)
          if (_isRobotSpeaking)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildHeaderIconButton(
                icon: Icons.pan_tool_rounded,
                color: Colors.white,
                backgroundColor: const Color(0xCCFF9100),
                tooltip: 'Ngắt lời robot',
                onPressed: _sendAbortMessage,
              ),
            ),

          // Nút tắt / mở loa (mute)
          _buildHeaderIconButton(
            icon: isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: isMuted ? AppTheme.errorColor : Colors.white70,
            tooltip: isMuted ? 'Bật âm thanh' : 'Tắt âm thanh',
            onPressed: () {
              _xiaozhiService?.toggleMute();
              setState(() {});
            },
          ),
          const SizedBox(width: 8),

          // Nút xem nhật ký hệ thống
          _buildHeaderIconButton(
            icon: Icons.article_outlined,
            color: Colors.white70,
            tooltip: 'Nhật ký hệ thống',
            onPressed: _openLogScreen,
          ),
        ],
      ),
    );
  }

  /// Nút icon hình tròn nhỏ ở thanh tiêu đề
  Widget _buildHeaderIconButton({
    required IconData icon,
    required Color color,
    Color backgroundColor = const Color(0x1AFFFFFF),
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x3300F0FF), width: 0.8),
      ),
      child: Material(
        color: Colors.transparent,
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(icon, color: color, size: 18),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }

  /// Dải sóng âm cyan hiển thị mức âm thanh động
  Widget _buildAudioWaveform() {
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_audioLevels.length, (index) {
          final level = _audioLevels[index].clamp(0.06, 1.0);
          final barHeight = (level * 32.0).clamp(4.0, 32.0);
          return Container(
            width: 3.5,
            height: barHeight,
            margin: const EdgeInsets.symmetric(horizontal: 2.0),
            decoration: BoxDecoration(
              color: const Color(
                0xFF00F0FF,
              ).withOpacity((0.35 + 0.65 * level).clamp(0.0, 1.0)),
              borderRadius: BorderRadius.circular(2.0),
              boxShadow: [
                if (level > 0.3)
                  BoxShadow(
                    color: const Color(0xFF00F0FF).withOpacity(0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// Thanh điều khiển chân trang: Nhập văn bản | Micro lớn | Kết thúc
  Widget _buildBottomControls() {
    final bool isListeningActive =
        _isSpeaking && _sessionState == SessionState.listening;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Nút chuyển sang chế độ chat nhập văn bản
        _buildBottomActionButton(
          icon: Icons.chat_bubble_outline_rounded,
          color: const Color(0xFF00F0FF),
          backgroundColor: const Color(0x1A00F0FF),
          borderColor: const Color(0x5500F0FF),
          size: 52,
          tooltip: 'Nhập văn bản',
          onPressed: _switchToChat,
        ),

        // 2. Nút Microphone lớn ở giữa
        _buildBigMicButton(isListeningActive: isListeningActive),

        // 3. Nút kết thúc cuộc gọi
        _buildBottomActionButton(
          icon: Icons.call_end_rounded,
          color: Colors.white,
          backgroundColor: AppTheme.errorColor,
          borderColor: AppTheme.errorColor.withOpacity(0.6),
          size: 52,
          tooltip: 'Kết thúc cuộc gọi',
          onPressed: () async {
            _otaCancelToken?.cancel();
            await _xiaozhiService?.sendAbortMessage();
            await _xiaozhiService?.stopListeningCall();
            _xiaozhiService?.stopPlayback();
            await _v2Bridge.endConversation();
            if (mounted) {
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }

  /// Nút Microphone chính lớn
  Widget _buildBigMicButton({required bool isListeningActive}) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color:
            isListeningActive
                ? const Color(0xFF00F0FF)
                : const Color(0xFF0A1520),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF00F0FF), width: 2.0),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF00F0FF,
            ).withOpacity(isListeningActive ? 0.7 : 0.25),
            blurRadius: isListeningActive ? 22 : 10,
            spreadRadius: isListeningActive ? 3 : 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _handleBigMicButton,
          child: Center(
            child: Icon(
              isListeningActive ? Icons.mic_rounded : Icons.mic_none_rounded,
              color:
                  isListeningActive
                      ? const Color(0xFF070B12)
                      : const Color(0xFF00F0FF),
              size: 36,
            ),
          ),
        ),
      ),
    );
  }

  /// Nút hành động tròn ở thanh dưới
  Widget _buildBottomActionButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required Color borderColor,
    required double size,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Center(child: Icon(icon, color: color, size: size * 0.46)),
          ),
        ),
      ),
    );
  }

  /// Lớp phủ kích hoạt thiết bị hiển thị mã 6 số phong cách Cyber HUD Cyan
  Widget _buildActivationOverlay() {
    return Positioned.fill(
      child: Container(
        color: AppTheme.backgroundColor.withOpacity(0.96),
        child: SafeArea(
          child: Column(
            children: [
              // Thanh tiêu đề với nút quay lại
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppTheme.primaryColor,
                      size: 26,
                    ),
                    onPressed: () {
                      _otaCancelToken?.cancel();
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 28.0,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.15),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Tiêu đề
                          const Text(
                            'KÍCH HOẠT THIẾT BỊ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (_otaError != null) ...[
                            // Trạng thái LỖI
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.errorColor.withOpacity(0.4),
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: AppTheme.errorColor,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Lỗi kết nối máy chủ',
                                    style: TextStyle(
                                      color: AppTheme.errorColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    _otaError!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppTheme.textColor,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _startActivationFlow,
                              icon: const Icon(Icons.refresh, size: 20),
                              label: const Text(
                                'Thử lại',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: AppTheme.backgroundColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ] else if (_isOtaConnecting &&
                              _activationCode == null) ...[
                            // Trạng thái ĐANG GỌI OTA
                            const SizedBox(height: 20),
                            const SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                strokeWidth: 3.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Đang kết nối máy chủ...',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _otaStatus.isNotEmpty
                                  ? _otaStatus
                                  : 'Đang gửi yêu cầu kiểm tra OTA',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.secondaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ] else if (_activationCode != null) ...[
                            // Trạng thái HIỂN THỊ MÃ KÍCH HOẠT
                            const Text(
                              'MÃ KÍCH HOẠT',
                              style: TextStyle(
                                fontSize: 13,
                                letterSpacing: 1.2,
                                color: AppTheme.secondaryTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundColor.withOpacity(
                                  0.8,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.accentColor.withOpacity(0.5),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                _activationCode!.split('').join(' '),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 6.0,
                                  color: AppTheme.accentColor,
                                  shadows: [
                                    Shadow(
                                      color: AppTheme.accentColor.withOpacity(
                                        0.8,
                                      ),
                                      blurRadius: 18,
                                    ),
                                    Shadow(
                                      color: AppTheme.primaryColor.withOpacity(
                                        0.6,
                                      ),
                                      blurRadius: 36,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundColor.withOpacity(
                                  0.5,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Vào xiaozhi.me -> Bảng điều khiển -> Thêm thiết bị -> nhập mã này',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textColor,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(text: _activationCode!),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Đã sao chép mã: $_activationCode',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.copy,
                                    size: 14,
                                    color: AppTheme.accentColor,
                                  ),
                                  label: const Text(
                                    'Sao chép mã',
                                    style: TextStyle(
                                      color: AppTheme.accentColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: AppTheme.accentColor,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(
                                        text: _currentConfig.macAddress,
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Đã sao chép MAC: ${_currentConfig.macAddress}',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.copy,
                                    size: 14,
                                    color: AppTheme.primaryColor,
                                  ),
                                  label: Text(
                                    'MAC: ${_currentConfig.macAddress}',
                                    style: const TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: AppTheme.primaryColor,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.accentColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _otaStatus.isNotEmpty
                                        ? _otaStatus
                                        : 'Đang chờ kích hoạt...',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.secondaryTextColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _startActivationFlow,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text(
                                'Lấy mã mới',
                                style: TextStyle(fontSize: 14),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.accentColor,
                                side: BorderSide(
                                  color: AppTheme.accentColor.withOpacity(0.6),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),
                          Text(
                            'MAC: ${_currentConfig.macAddress}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.secondaryTextColor,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hiển thị thông báo Snackbar tùy biến
  void _showCustomSnackbar({
    required String message,
    required IconData icon,
    required Color iconColor,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1E293B),
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 6,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}
