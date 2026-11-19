import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:ai_assistant/models/conversation.dart';
import 'package:ai_assistant/models/message.dart';
import 'package:ai_assistant/models/xiaozhi_config.dart';
import 'package:ai_assistant/providers/conversation_provider.dart';
import 'package:ai_assistant/providers/config_provider.dart';
import 'package:ai_assistant/services/xiaozhi_service.dart';
import 'package:ai_assistant/services/xiaozhi_ota_service.dart';
import 'package:ai_assistant/utils/device_util.dart';
import 'package:ai_assistant/widgets/message_bubble.dart';
import 'package:ai_assistant/screens/voice_call_screen.dart';
import 'package:ai_assistant/utils/app_theme.dart';
import 'package:ai_assistant/utils/app_log.dart';
import 'package:ai_assistant/widgets/ai_avatar_widget.dart';
import 'package:ai_assistant/widgets/robot_face.dart';

class ChatScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  XiaozhiService? _xiaozhiService;
  final XiaozhiOtaService _otaService = XiaozhiOtaService();
  OtaCancellationToken? _otaCancelToken;
  late XiaozhiConfig _currentConfig;
  FaceState _aiState = FaceState.idle;
  String _aiEmotion = 'neutral';

  // Trạng thái kích hoạt OTA
  bool _isOtaActivating = false;
  bool _isOtaLoading = false;
  String? _activationCode;
  String _otaStatus = '';
  String? _otaError;

  Timer? _connectionCheckTimer;
  Timer? _autoReconnectTimer;

  // Thu âm giọng nói
  bool _isVoiceInputMode = true;
  bool _isRecording = false;
  bool _isCancelling = false;
  double _startDragY = 0.0;
  final double _cancelThreshold = 50.0;
  Timer? _waveAnimationTimer;
  final List<double> _waveHeights = List.filled(20, 0.0);
  final Random _random = Random();
  String? _lastSavedUserSentence;
  String? _lastSavedAssistantSentence;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      );

      Provider.of<ConversationProvider>(
        context,
        listen: false,
      ).markConversationAsRead(widget.conversation.id);

      _initXiaozhiService();

      _connectionCheckTimer = Timer.periodic(const Duration(seconds: 2), (
        timer,
      ) {
        if (mounted && _xiaozhiService != null) {
          final wasConnected = _xiaozhiService!.isConnected;
          setState(() {});

          if (wasConnected &&
              !_xiaozhiService!.isConnected &&
              !_xiaozhiService!.isVoiceCallActive &&
              _autoReconnectTimer == null &&
              !_isOtaActivating) {
            _scheduleReconnect();
          }
        }
      });
    });
  }

  void _scheduleReconnect() {
    _autoReconnectTimer?.cancel();
    _autoReconnectTimer = Timer(const Duration(seconds: 5), () async {
      _autoReconnectTimer = null;
      if (mounted &&
          _xiaozhiService != null &&
          !_xiaozhiService!.isConnected &&
          !_xiaozhiService!.isVoiceCallActive &&
          !_isOtaActivating) {
        try {
          await _xiaozhiService!.connect();
          if (mounted) setState(() {});
          if (!_xiaozhiService!.isConnected) {
            _scheduleReconnect();
          }
        } catch (_) {
          _scheduleReconnect();
        }
      }
    });
  }

  @override
  void dispose() {
    _otaCancelToken?.cancel();
    _connectionCheckTimer?.cancel();
    _autoReconnectTimer?.cancel();
    _waveAnimationTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();

    if (_xiaozhiService != null) {
      _xiaozhiService!.stopPlayback();
    }

    super.dispose();
  }

  Future<void> _initXiaozhiService() async {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    final String? configId = widget.conversation.configId;

    _currentConfig = configProvider.xiaozhiConfigs.firstWhere(
      (config) => config.id == configId,
      orElse:
          () =>
              configProvider.xiaozhiConfigs.isNotEmpty
                  ? configProvider.xiaozhiConfigs.first
                  : XiaozhiConfig(
                    id: 'default_botai',
                    name: 'botAi',
                    otaUrl: XiaozhiConfig.defaultOtaUrl,
                    websocketUrl: '',
                    macAddress: '',
                    token: 'test-token',
                  ),
    );

    await _startOtaActivation();
  }

  /// Quy trình kiểm tra và chờ kích hoạt OTA trước khi kết nối WebSocket
  Future<void> _startOtaActivation() async {
    _otaCancelToken?.cancel();
    final cancelToken = OtaCancellationToken();
    _otaCancelToken = cancelToken;

    final mac =
        DeviceUtil.isValidMac(_currentConfig.macAddress)
            ? _currentConfig.macAddress
            : await DeviceUtil.getDeviceMac();
    final clientId = await DeviceUtil.getClientId();

    if (_currentConfig.macAddress != mac) {
      _currentConfig = _currentConfig.copyWith(macAddress: mac);
    }

    setState(() {
      _isOtaActivating = true;
      _isOtaLoading = true;
      _otaError = null;
      _activationCode = null;
      _otaStatus = 'Đang kết nối máy chủ...';
    });

    try {
      final result = await _otaService.ensureActivated(
        otaUrl: _currentConfig.otaUrl,
        mac: mac,
        clientId: clientId,
        onActivationCode: (code) {
          if (!mounted || cancelToken.isCancelled) return;
          setState(() {
            _activationCode = code;
            _isOtaLoading = false;
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
        _isOtaActivating = false;
        _isOtaLoading = false;
        _otaError = null;
      });

      _xiaozhiService = XiaozhiService(
        websocketUrl: updatedConfig.websocketUrl,
        macAddress: updatedConfig.macAddress,
        clientId: clientId,
        token: updatedConfig.token,
        sessionId: widget.conversation.id,
      );

      _xiaozhiService!.setMessageListener(_handleXiaozhiMessage);
      _xiaozhiService!.addListener(_handleXiaozhiEvent);

      await _xiaozhiService!.connect();
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted || cancelToken.isCancelled) return;
      print('Lỗi kích hoạt OTA ChatScreen: $e');
      setState(() {
        _isOtaLoading = false;
        _otaError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _handleXiaozhiMessage(dynamic message) {
    if (!mounted) return;

    if (message is Map<String, dynamic>) {
      final String? type = message['type'];
      final String? msgState = message['state'];
      final dynamic emo = message['emotion'];

      // Cập nhật biểu cảm cảm xúc AI
      if (emo is String && emo.trim().isNotEmpty) {
        if (_aiEmotion != emo.trim()) {
          setState(() => _aiEmotion = emo.trim());
        }
      }

      // Cập nhật trạng thái động của robot
      if (type == 'tts') {
        if (msgState == 'start' || msgState == 'sentence_start') {
          if (_aiState != FaceState.speaking) {
            setState(() => _aiState = FaceState.speaking);
          }
        } else if (msgState == 'stop') {
          if (_aiState != FaceState.idle) {
            setState(() => _aiState = FaceState.idle);
          }
        }
      } else if (type == 'stt') {
        if (_aiState != FaceState.listening) {
          setState(() => _aiState = FaceState.listening);
        }
      } else if (type == 'listen') {
        if (msgState == 'start') {
          if (_aiState != FaceState.listening) {
            setState(() => _aiState = FaceState.listening);
          }
        } else if (msgState == 'stop') {
          if (_aiState != FaceState.thinking) {
            setState(() => _aiState = FaceState.thinking);
          }
        }
      }

      final content = message['text'] ?? message['content'];

      if (content != null && content.toString().trim().isNotEmpty) {
        final text = content.toString().trim();
        if (type == 'stt') {
          if (_isVoiceInputMode) {
            if (text == _lastSavedUserSentence) return;
            _lastSavedUserSentence = text;
            _lastSavedAssistantSentence = null;
            AppLog.add('[Chat] STT nguoi dung: $text');
            Future.microtask(() {
              if (mounted) {
                Provider.of<ConversationProvider>(
                  context,
                  listen: false,
                ).addMessage(
                  conversationId: widget.conversation.id,
                  role: MessageRole.user,
                  content: text,
                );
                _scrollToBottom();
              }
            });
          }
        } else if (type == 'tts' || type == 'llm') {
          final String? state = message['state'];
          // Voi type tts, chi luu cau khi state la sentence_start
          if (type == 'tts' && state != null && state != 'sentence_start') {
            return;
          }
          if (text == _lastSavedAssistantSentence) return;
          _lastSavedAssistantSentence = text;
          _lastSavedUserSentence = null;
          AppLog.add('[Chat] Robot tra loi: $text');
          Future.microtask(() {
            if (mounted) {
              Provider.of<ConversationProvider>(
                context,
                listen: false,
              ).addMessage(
                conversationId: widget.conversation.id,
                role: MessageRole.assistant,
                content: text,
              );
              _scrollToBottom();
            }
          });
        }
      }
    }
  }

  void _handleXiaozhiEvent(XiaozhiServiceEvent event) {
    if (!mounted) return;
    if (event.type == XiaozhiServiceEventType.connected) {
      setState(() => _aiState = FaceState.idle);
    } else if (event.type == XiaozhiServiceEventType.disconnected) {
      setState(() => _aiState = FaceState.idle);
    } else if (event.type == XiaozhiServiceEventType.userMessage) {
      setState(() => _aiState = FaceState.thinking);
    } else if (event.type == XiaozhiServiceEventType.textMessage) {
      setState(() => _aiState = FaceState.speaking);
    } else {
      setState(() {});
    }
  }

  String _getAiStateLabel() {
    switch (_aiState) {
      case FaceState.listening:
        return '🎤 Đang nghe...';
      case FaceState.thinking:
        return '⚡ Đang suy nghĩ...';
      case FaceState.speaking:
        return '🗣️ Đang trả lời...';
      case FaceState.connecting:
        return '🔄 Đang kết nối...';
      case FaceState.error:
        return '⚠️ Mất kết nối';
      case FaceState.idle:
      default:
        return '🤖 Sẵn sàng';
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        toolbarHeight: 70,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppTheme.primaryColor,
            size: 26,
          ),
          onPressed: () {
            if (_xiaozhiService != null) {
              _xiaozhiService!.stopPlayback();
            }
            Navigator.of(context).pop();
          },
        ),
        title: Row(
          children: [
            AiAvatarWidget(
              state: _aiState,
              emotion: _aiEmotion,
              size: 40,
              service: _xiaozhiService,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.title,
                    style: const TextStyle(
                      color: AppTheme.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.4),
                      ),
                    ),
                    child: const Text(
                      'Thoại Xiaozhi',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _navigateToVoiceCall,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.4),
                      ),
                    ),
                    child: const Icon(
                      Icons.phone,
                      color: AppTheme.primaryColor,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isOtaActivating) _buildActivationBanner(),
          _buildXiaozhiInfo(),
          Expanded(child: _buildMessageList()),
          _buildInputArea(),
        ],
      ),
    );
  }

  /// Banner hiển thị mã kích hoạt 6 số trong màn hình Chat
  Widget _buildActivationBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'KÍCH HOẠT THIẾT BỊ',
            style: TextStyle(
              color: Color(0xFF00E5FF),
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          if (_otaError != null) ...[
            Text(
              _otaError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _startOtaActivation,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
              ),
            ),
          ] else if (_isOtaLoading && _activationCode == null) ...[
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _otaStatus.isNotEmpty ? _otaStatus : 'Đang kết nối máy chủ...',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ] else if (_activationCode != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00F0FF).withOpacity(0.5),
                ),
              ),
              child: Text(
                _activationCode!.split('').join(' '),
                style: const TextStyle(
                  color: Color(0xFF00F0FF),
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4.0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Vào xiaozhi.me -> Bảng điều khiển -> Thêm thiết bị -> nhập mã này',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _activationCode!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đã sao chép mã: $_activationCode'),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.copy,
                    size: 14,
                    color: Color(0xFF00F0FF),
                  ),
                  label: const Text(
                    'Sao chép mã',
                    style: TextStyle(color: Color(0xFF00F0FF), fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF00F0FF)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _currentConfig.macAddress),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Đã sao chép MAC: ${_currentConfig.macAddress}',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 14, color: Colors.white),
                  label: Text(
                    'MAC: ${_currentConfig.macAddress}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF00F0FF),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _otaStatus.isNotEmpty ? _otaStatus : 'Đang chờ kích hoạt...',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _startOtaActivation,
                  child: const Text(
                    'Lấy mã mới',
                    style: TextStyle(color: Color(0xFF00F0FF)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildXiaozhiInfo() {
    final configProvider = Provider.of<ConfigProvider>(context);
    final xiaozhiConfig = configProvider.xiaozhiConfigs.firstWhere(
      (config) => config.id == widget.conversation.configId,
      orElse:
          () => XiaozhiConfig(
            id: '',
            name: 'botAi',
            websocketUrl: '',
            macAddress: '',
            token: '',
          ),
    );

    final bool isConnected = _xiaozhiService?.isConnected ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected ? Colors.green : AppTheme.errorColor,
              boxShadow: [
                BoxShadow(
                  color: (isConnected ? Colors.green : AppTheme.errorColor)
                      .withOpacity(0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isConnected ? 'Đã kết nối' : 'Chưa kết nối',
            style: TextStyle(
              fontSize: 13,
              color: isConnected ? Colors.green : AppTheme.errorColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 16, color: AppTheme.borderColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              xiaozhiConfig.websocketUrl.isNotEmpty
                  ? xiaozhiConfig.websocketUrl
                  : 'Chưa cấu hình URL',
              style: const TextStyle(
                color: AppTheme.secondaryTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getAiStateLabel(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                if (_aiEmotion != 'neutral') ...[
                  const SizedBox(width: 4),
                  Text(
                    '($_aiEmotion)',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.secondaryTextColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return Consumer<ConversationProvider>(
      builder: (context, provider, child) {
        final messages = provider.getMessages(widget.conversation.id);

        if (messages.isEmpty) {
          return const Center(
            child: Text(
              'Bắt đầu cuộc trò chuyện',
              style: TextStyle(
                color: AppTheme.secondaryTextColor,
                fontSize: 16,
              ),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          reverse: true,
          itemCount: messages.length + (_isLoading ? 1 : 0),
          cacheExtent: 1000.0,
          physics: const ClampingScrollPhysics(),
          itemBuilder: (context, index) {
            if (_isLoading && index == 0) {
              return MessageBubble(
                message: Message(
                  id: 'loading',
                  conversationId: '',
                  role: MessageRole.assistant,
                  content: 'Đang xử lý...',
                  timestamp: DateTime.now(),
                ),
                isThinking: true,
                conversationType: widget.conversation.type,
              );
            }

            final adjustedIndex = _isLoading ? index - 1 : index;
            final message = messages[messages.length - 1 - adjustedIndex];

            return RepaintBoundary(
              child: MessageBubble(
                key: ValueKey(message.id),
                message: message,
                conversationType: widget.conversation.type,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInputArea() {
    final bool hasText = _textController.text.trim().isNotEmpty;

    if (_isVoiceInputMode) {
      return _buildVoiceInputArea();
    } else {
      return _buildTextInputArea(hasText);
    }
  }

  Widget _buildTextInputArea(bool hasText) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: const Border(top: BorderSide(color: AppTheme.borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        top: 16,
        right: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      hintStyle: TextStyle(
                        color: AppTheme.secondaryTextColor,
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    style: const TextStyle(
                      color: AppTheme.textColor,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                _buildSendButton(hasText),
                IconButton(
                  icon: const Icon(
                    Icons.mic,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      _isVoiceInputMode = true;
                    });
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceInputArea() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: const Border(top: BorderSide(color: AppTheme.borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        top: 16,
        right: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              onLongPressStart: (details) {
                setState(() {
                  _isRecording = true;
                  _isCancelling = false;
                  _startDragY = details.globalPosition.dy;
                });
                _startRecording();
                _startWaveAnimation();
              },
              onLongPressMoveUpdate: (details) {
                final double dragDistance =
                    _startDragY - details.globalPosition.dy;

                if (dragDistance > _cancelThreshold && !_isCancelling) {
                  setState(() {
                    _isCancelling = true;
                  });
                  HapticFeedback.mediumImpact();
                } else if (dragDistance <= _cancelThreshold && _isCancelling) {
                  setState(() {
                    _isCancelling = false;
                  });
                  HapticFeedback.lightImpact();
                }
              },
              onLongPressEnd: (details) {
                final wasRecording = _isRecording;
                final wasCancelling = _isCancelling;

                setState(() {
                  _isRecording = false;
                });

                _stopWaveAnimation();

                if (wasRecording) {
                  if (wasCancelling) {
                    _cancelRecording();
                  } else {
                    _stopRecording();
                  }
                }
              },
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color:
                      _isRecording
                          ? _isCancelling
                              ? AppTheme.errorColor.withOpacity(0.2)
                              : AppTheme.primaryColor.withOpacity(0.2)
                          : AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color:
                        _isRecording
                            ? _isCancelling
                                ? AppTheme.errorColor
                                : AppTheme.primaryColor
                            : AppTheme.borderColor,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      spreadRadius: 0,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isRecording && !_isCancelling)
                      _buildWaveAnimationIndicator(),
                    Center(
                      child: Text(
                        _isRecording
                            ? _isCancelling
                                ? "Thả tay để hủy gửi"
                                : "Thả để gửi, trượt lên để hủy"
                            : "Nhấn giữ để nói",
                        style: TextStyle(
                          color:
                              _isRecording
                                  ? _isCancelling
                                      ? AppTheme.errorColor
                                      : AppTheme.primaryColor
                                  : AppTheme.textColor,
                          fontSize: 16,
                          fontWeight:
                              _isRecording
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: () {
                  if (_isRecording) {
                    _cancelRecording();
                    _stopWaveAnimation();
                  }
                  setState(() {
                    _isVoiceInputMode = false;
                    _isRecording = false;
                    _isCancelling = false;
                  });
                },
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Icon(
                    Icons.keyboard,
                    color: AppTheme.primaryColor,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(bool hasText) {
    return IconButton(
      key: const ValueKey('send_button'),
      icon: Icon(
        Icons.send_rounded,
        color:
            hasText
                ? AppTheme.primaryColor
                : AppTheme.secondaryTextColor.withOpacity(0.4),
        size: 24,
      ),
      onPressed: hasText ? _sendMessage : null,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      constraints: const BoxConstraints(),
    );
  }

  void _startRecording() async {
    if (_xiaozhiService == null) {
      _showCustomSnackbar('Chưa kết nối đến dịch vụ Xiaozhi');
      setState(() {
        _isVoiceInputMode = false;
      });
      return;
    }

    try {
      HapticFeedback.mediumImpact();
      AppLog.add('[Chat] Nhan giu mic -> Bat dau thu am manual');
      await _xiaozhiService!.switchToChatMode();
      await _xiaozhiService!.startListening(mode: 'manual');
    } catch (e) {
      AppLog.add('[Chat] Loi ghi am: $e');
      _showCustomSnackbar('Không thể bắt đầu ghi âm: ${e.toString()}');
      setState(() {
        _isRecording = false;
        _isVoiceInputMode = false;
      });
    }
  }

  void _stopRecording() async {
    try {
      setState(() {
        _isLoading = true;
        _isRecording = false;
      });

      HapticFeedback.mediumImpact();
      AppLog.add('[Chat] Tha tay mic -> Dung thu am (listen stop)');
      await _xiaozhiService?.stopListening();
      _scrollToBottom();
    } catch (e) {
      AppLog.add('[Chat] Loi gui giong noi: $e');
      _showCustomSnackbar('Gửi giọng nói thất bại: ${e.toString()}');
      setState(() {
        _isVoiceInputMode = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _cancelRecording() async {
    try {
      setState(() {
        _isRecording = false;
      });

      HapticFeedback.heavyImpact();
      await _xiaozhiService?.abortListening();
      _showCustomSnackbar('Đã hủy gửi');
    } catch (_) {}
  }

  void _showCustomSnackbar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final snackBar = SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          color: AppTheme.textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppTheme.surfaceColor,
      duration: const Duration(seconds: 2),
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height - 120,
        left: 16,
        right: 16,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      elevation: 8,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _sendMessage() async {
    final message = _textController.text.trim();
    if (message.isEmpty || _isLoading) return;

    if (_isOtaActivating) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Vui lòng kích hoạt thiết bị trên xiaozhi.me trước khi trò chuyện',
            style: TextStyle(color: AppTheme.textColor),
          ),
          backgroundColor: AppTheme.surfaceColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppTheme.primaryColor),
          ),
        ),
      );
      return;
    }

    _textController.clear();

    final conversationProvider = Provider.of<ConversationProvider>(
      context,
      listen: false,
    );

    await conversationProvider.addMessage(
      conversationId: widget.conversation.id,
      role: MessageRole.user,
      content: message,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      if (_xiaozhiService == null) {
        await _initXiaozhiService();
      } else if (!_xiaozhiService!.isConnected) {
        await _xiaozhiService!.connect();
        if (!_xiaozhiService!.isConnected) {
          throw Exception(
            "Không thể kết nối đến dịch vụ Xiaozhi, vui lòng kiểm tra mạng",
          );
        }
        setState(() {});
      }

      await _xiaozhiService!.sendTextMessage(message);
    } catch (e) {
      if (!mounted) return;

      await conversationProvider.addMessage(
        conversationId: widget.conversation.id,
        role: MessageRole.assistant,
        content: 'Đã xảy ra lỗi: ${e.toString()}',
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _navigateToVoiceCall() {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    final xiaozhiConfig = configProvider.xiaozhiConfigs.firstWhere(
      (config) => config.id == widget.conversation.configId,
      orElse:
          () =>
              configProvider.xiaozhiConfigs.isNotEmpty
                  ? configProvider.xiaozhiConfigs.first
                  : XiaozhiConfig(
                    id: 'default_botai',
                    name: 'botAi',
                    otaUrl: XiaozhiConfig.defaultOtaUrl,
                    websocketUrl: '',
                    macAddress: '',
                    token: 'test-token',
                  ),
    );

    if (_xiaozhiService != null) {
      _xiaozhiService!.stopPlayback();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => VoiceCallScreen(
              conversation: widget.conversation,
              xiaozhiConfig: xiaozhiConfig,
            ),
      ),
    ).then((_) async {
      AppLog.add('[Chat] Quay ve tu VoiceCallScreen -> Khoi phuc che do chat');
      if (_xiaozhiService == null) {
        await _initXiaozhiService();
        return;
      }

      // Đảm bảo chuyển về chế độ chat
      await _xiaozhiService!.switchToChatMode();

      // Đăng ký lại listener chat
      _xiaozhiService!.setMessageListener(_handleXiaozhiMessage);
      _xiaozhiService!.addListener(_handleXiaozhiEvent);

      // Đảm bảo đang kết nối và đã có session_id (chờ 'hello' nếu vừa kết nối lại)
      if (!_xiaozhiService!.isConnected) {
        AppLog.add('[Chat] Service chua ket noi, dang ket noi lai...');
        await _xiaozhiService!.connect();
        await _xiaozhiService!.waitForHello(
          timeout: const Duration(seconds: 8),
        );
      } else if (_xiaozhiService!.sessionId == null) {
        AppLog.add(
          '[Chat] Service da ket noi nhung chua co session_id, cho hello...',
        );
        await _xiaozhiService!.waitForHello(
          timeout: const Duration(seconds: 8),
        );
      }

      if (mounted) setState(() {});
    });
  }

  void _startWaveAnimation() {
    _waveAnimationTimer?.cancel();
    _waveAnimationTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (_isRecording && !_isCancelling) {
        setState(() {
          for (int i = 0; i < _waveHeights.length; i++) {
            _waveHeights[i] = 0.5 + _random.nextDouble() * 0.5;
          }
        });
      }
    });
  }

  void _stopWaveAnimation() {
    _waveAnimationTimer?.cancel();
    _waveAnimationTimer = null;
  }

  Widget _buildWaveAnimationIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          16,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 3,
            height: 20 * _waveHeights[index],
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(1.5),
            ),
            curve: Curves.easeInOut,
          ),
        ),
      ),
    );
  }
}
