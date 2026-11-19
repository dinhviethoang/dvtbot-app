import 'dart:convert';
import 'package:flutter/services.dart';
import '../assistant_v2/assistant_v2_bridge.dart';
import '../utils/app_log.dart';

/// Các loại hành động hệ thống được hỗ trợ (P0.2)
enum AssistantActionType {
  openMaps,
  openYoutube,
  openApp,
  back,
  home,
  recents,
  scroll,
  clickText,
  setVolume,
  adjustVolume,
  toggleFlashlight,
  openSettings,
}

/// Kết quả thực thi hành động bất đồng bộ có cấu trúc (P0.2)
class AssistantActionResult {
  final bool success;
  final AssistantActionType action;
  final String message;
  final Map<String, Object?> data;

  const AssistantActionResult({
    required this.success,
    required this.action,
    required this.message,
    this.data = const {},
  });

  @override
  String toString() =>
      'AssistantActionResult(success: $success, action: ${action.name}, message: "$message")';
}

/// Bộ thực thi lệnh hệ thống (System Assistant Action Engine)
/// Điều khiển điện thoại Android như Google Assistant thông qua Intent & MethodChannel
class AssistantActionExecutor {
  static const MethodChannel _channel = MethodChannel(
    'com.lhht.ai_assistant/system_action',
  );

  static final AssistantV2Bridge _v2Bridge = AssistantV2Bridge();
  static bool _flashlightState = false;

  /// Điều hướng Trợ năng (Accessibility Navigation)
  static Future<bool> performBack() async {
    try {
      AppLog.add('[Action] Thực hiện thao tác QUAY LẠI (BACK)');
      return await _v2Bridge.back();
    } catch (e) {
      AppLog.add('[Lỗi] performBack: $e');
      return false;
    }
  }

  static Future<bool> performHome() async {
    try {
      AppLog.add('[Action] Thực hiện thao tác VỀ MÀN HÌNH CHÍNH (HOME)');
      return await _v2Bridge.home();
    } catch (e) {
      AppLog.add('[Lỗi] performHome: $e');
      return false;
    }
  }

  static Future<bool> openRecents() async {
    try {
      AppLog.add('[Action] Thực hiện thao tác MỞ ĐA NHIỆM (RECENTS)');
      return await _v2Bridge.recents();
    } catch (e) {
      AppLog.add('[Lỗi] openRecents: $e');
      return false;
    }
  }

  static Future<bool> scrollForward() async {
    try {
      AppLog.add('[Action] Thực hiện thao tác CUỘN XUỐNG (SCROLL_FORWARD)');
      return await _v2Bridge.scrollForward();
    } catch (e) {
      AppLog.add('[Lỗi] scrollForward: $e');
      return false;
    }
  }

  static Future<bool> clickVisibleText(String label) async {
    try {
      AppLog.add('[Action] Thực hiện thao tác NHẤN VĂN BẢN: "$label"');
      return await _v2Bridge.clickVisibleText(label);
    } catch (e) {
      AppLog.add('[Lỗi] clickVisibleText: $e');
      return false;
    }
  }

  static Future<bool> isAccessibilityEnabled() async {
    try {
      return await _v2Bridge.isAccessibilityEnabled();
    } catch (e) {
      return false;
    }
  }

  static Future<void> openAccessibilitySettings() async {
    try {
      AppLog.add('[Action] Mở Cài đặt Trợ năng Android');
      await _v2Bridge.openAccessibilitySettings();
    } catch (e) {
      AppLog.add('[Lỗi] openAccessibilitySettings: $e');
    }
  }

  /// 1. Chỉ đường / Tìm địa điểm trên Google Maps (OPEN_MAP)
  static Future<Map<dynamic, dynamic>> openGoogleMaps(
    String destination,
  ) async {
    try {
      AppLog.add('[Action] Mở Google Maps: $destination');
      final result = await _channel.invokeMethod('openGoogleMaps', {
        'destination': destination,
      });
      return result is Map ? result : {'success': true};
    } catch (e) {
      AppLog.add('[Lỗi] openGoogleMaps: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 2. Tìm và phát video/nhạc trên YouTube (OPEN_YOUTUBE)
  static Future<Map<dynamic, dynamic>> openYouTube(String query) async {
    try {
      AppLog.add('[Action] Mở YouTube: $query');
      final result = await _channel.invokeMethod('openYouTube', {
        'query': query,
      });
      return result is Map ? result : {'success': true};
    } catch (e) {
      AppLog.add('[Lỗi] openYouTube: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 3. Mở bất kỳ ứng dụng nào trong máy (OPEN_APP)
  static Future<Map<dynamic, dynamic>> openApp(String appName) async {
    try {
      AppLog.add('[Action] Mở ứng dụng: $appName');
      final result = await _channel.invokeMethod('openApp', {
        'appName': appName,
      });
      return result is Map ? result : {'success': true};
    } catch (e) {
      AppLog.add('[Lỗi] openApp: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 4. Gọi điện thoại (MAKE_CALL)
  static Future<Map<dynamic, dynamic>> makePhoneCall(String phoneNumber) async {
    try {
      AppLog.add('[Action] Gọi điện thoại: $phoneNumber');
      final result = await _channel.invokeMethod('makePhoneCall', {
        'phoneNumber': phoneNumber,
      });
      return result is Map ? result : {'success': true};
    } catch (e) {
      AppLog.add('[Lỗi] makePhoneCall: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 5. Điều khiển âm lượng (STREAM_MUSIC)
  static Future<Map<dynamic, dynamic>> setVolume(int level) async {
    try {
      AppLog.add('[Action] Đặt âm lượng: $level%');
      final result = await _channel.invokeMethod('setVolume', {'level': level});
      return result is Map ? result : {'success': true};
    } catch (e) {
      AppLog.add('[Lỗi] setVolume: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<dynamic, dynamic>> adjustVolume(bool up) async {
    try {
      AppLog.add('[Action] ${up ? "Tăng" : "Giảm"} âm lượng');
      final result = await _channel.invokeMethod('adjustVolume', {'up': up});
      return result is Map ? result : {'success': true};
    } catch (e) {
      AppLog.add('[Lỗi] adjustVolume: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Bật / Tắt đèn pin
  static Future<Map<dynamic, dynamic>> toggleFlashlight({bool? state}) async {
    try {
      final targetState = state ?? !_flashlightState;
      AppLog.add('[Action] ${targetState ? "Bật" : "Tắt"} đèn pin');
      final result = await _channel.invokeMethod('toggleFlashlight', {
        'state': targetState,
      });
      _flashlightState = targetState;
      return result is Map ? result : {'success': true};
    } catch (e) {
      AppLog.add('[Lỗi] toggleFlashlight: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Cài đặt Wi-Fi
  static Future<Map<dynamic, dynamic>> openWifiSettings() async {
    try {
      AppLog.add('[Action] Mở cài đặt Wi-Fi');
      final result = await _channel.invokeMethod('openWifiSettings');
      return result is Map ? result : {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Cài đặt Bluetooth
  static Future<Map<dynamic, dynamic>> openBluetoothSettings() async {
    try {
      AppLog.add('[Action] Mở cài đặt Bluetooth');
      final result = await _channel.invokeMethod('openBluetoothSettings');
      return result is Map ? result : {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Lấy thông tin pin & thời gian
  static Future<Map<dynamic, dynamic>> getSystemStatus() async {
    try {
      final result = await _channel.invokeMethod('getSystemStatus');
      return result is Map ? result : {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Kiểm tra quyền vẽ đè màn hình (Overlay)
  static Future<bool> checkOverlayPermission() async {
    try {
      final res = await _channel.invokeMethod('checkOverlayPermission');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  /// Mở màn hình cấp quyền vẽ đè (Overlay)
  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  /// Khởi chạy bong bóng nhân vật ảo nổi
  static Future<void> startFloatingAvatar([String state = 'idle']) async {
    try {
      await _channel.invokeMethod('startFloatingAvatar', {'state': state});
    } catch (_) {}
  }

  /// Tắt bong bóng nhân vật ảo nổi
  static Future<void> stopFloatingAvatar() async {
    try {
      await _channel.invokeMethod('stopFloatingAvatar');
    } catch (_) {}
  }

  /// Cập nhật trạng thái biểu cảm cho bong bóng nhân vật ảo nổi
  static Future<void> updateFloatingAvatarState(String state) async {
    try {
      await _channel.invokeMethod('updateFloatingAvatarState', {
        'state': state,
      });
    } catch (_) {}
  }

  /// Bản tin đăng ký Xiaozhi IoT Descriptor (Lớp 1)
  static Map<String, dynamic> buildIotDescriptorMessage() {
    return {
      "type": "iot",
      "descriptors": [
        {
          "name": "open_google_maps",
          "description": "Chỉ đường hoặc tìm kiếm vị trí trên Google Maps",
          "parameters": {
            "type": "object",
            "properties": {
              "location": {
                "type": "string",
                "description": "Tên địa điểm hoặc địa chỉ cần tìm/chỉ đường",
              },
            },
            "required": ["location"],
          },
        },
        {
          "name": "play_youtube",
          "description": "Tìm kiếm và phát video hoặc bài hát trên YouTube",
          "parameters": {
            "type": "object",
            "properties": {
              "query": {
                "type": "string",
                "description":
                    "Tên bài hát, video hoặc từ khóa tìm kiếm trên YouTube",
              },
            },
            "required": ["query"],
          },
        },
        {
          "name": "open_app",
          "description": "Mở một ứng dụng bất kỳ đã cài đặt trên điện thoại",
          "parameters": {
            "type": "object",
            "properties": {
              "app_name": {
                "type": "string",
                "description":
                    "Tên ứng dụng muốn mở (ví dụ: Zalo, Chrome, Cài đặt, Camera, Facebook)",
              },
            },
            "required": ["app_name"],
          },
        },
        {
          "name": "set_volume",
          "description": "Điều chỉnh mức âm lượng của thiết bị",
          "parameters": {
            "type": "object",
            "properties": {
              "level": {
                "type": "integer",
                "description": "Mức âm lượng từ 0 đến 100",
              },
            },
            "required": ["level"],
          },
        },
        {
          "name": "toggle_flashlight",
          "description": "Bật hoặc tắt đèn pin trên điện thoại",
          "parameters": {
            "type": "object",
            "properties": {
              "state": {
                "type": "boolean",
                "description": "true để bật đèn pin, false để tắt đèn pin",
              },
            },
            "required": ["state"],
          },
        },
        {
          "name": "system_back",
          "description": "Quay lại màn hình trước đó trên điện thoại",
          "parameters": {"type": "object", "properties": {}},
        },
        {
          "name": "system_home",
          "description": "Trở về màn hình chính (Home) của điện thoại",
          "parameters": {"type": "object", "properties": {}},
        },
        {
          "name": "system_recents",
          "description": "Mở danh sách các ứng dụng gần đây (đa nhiệm)",
          "parameters": {"type": "object", "properties": {}},
        },
        {
          "name": "scroll_screen",
          "description": "Cuộn màn hình xuống dưới để xem thêm nội dung",
          "parameters": {"type": "object", "properties": {}},
        },
        {
          "name": "click_screen_text",
          "description":
              "Nhấn vào văn bản hoặc nút hiển thị trên màn hình qua dịch vụ trợ năng",
          "parameters": {
            "type": "object",
            "properties": {
              "label": {
                "type": "string",
                "description":
                    "Tên chữ hoặc nhãn nút hiển thị trên màn hình cần nhấn",
              },
            },
            "required": ["label"],
          },
        },
        {
          "name": "open_accessibility_settings",
          "description":
              "Mở trang cài đặt trợ năng của Android để người dùng cấp quyền",
          "parameters": {"type": "object", "properties": {}},
        },
      ],
    };
  }

  /// Thực thi lệnh IoT chuẩn từ gói tin 'iot' của Xiaozhi Server (Lớp 1)
  static Future<void> handleIotPacket(Map<String, dynamic> jsonData) async {
    try {
      dynamic commandsRaw =
          jsonData['commands'] ?? jsonData['command'] ?? jsonData['actions'];
      List<dynamic> commandList = [];
      if (commandsRaw is List) {
        commandList = commandsRaw;
      } else if (commandsRaw is Map) {
        commandList = [commandsRaw];
      } else if (jsonData.containsKey('name')) {
        commandList = [jsonData];
      }

      for (var cmd in commandList) {
        if (cmd is! Map) continue;
        final name =
            (cmd['name'] ?? cmd['function'] ?? cmd['action'] ?? '').toString();
        final params =
            cmd['parameters'] ?? cmd['arguments'] ?? cmd['params'] ?? {};

        Map<String, dynamic> paramMap = {};
        if (params is String) {
          try {
            paramMap = jsonDecode(params) as Map<String, dynamic>;
          } catch (_) {
            paramMap = {
              'query': params,
              'location': params,
              'app_name': params,
            };
          }
        } else if (params is Map) {
          paramMap = Map<String, dynamic>.from(params);
        }

        switch (name) {
          case 'open_google_maps':
          case 'open_map':
            final location =
                (paramMap['location'] ??
                        paramMap['destination'] ??
                        paramMap['query'] ??
                        '')
                    .toString();
            if (location.isNotEmpty) {
              await openGoogleMaps(location);
            }
            break;

          case 'play_youtube':
          case 'open_youtube':
            final query =
                (paramMap['query'] ??
                        paramMap['keyword'] ??
                        paramMap['search'] ??
                        '')
                    .toString();
            if (query.isNotEmpty) {
              await openYouTube(query);
            }
            break;

          case 'open_app':
            final appName =
                (paramMap['app_name'] ??
                        paramMap['appName'] ??
                        paramMap['name'] ??
                        '')
                    .toString();
            if (appName.isNotEmpty) {
              await openApp(appName);
            }
            break;

          case 'set_volume':
            final level = paramMap['level'] ?? paramMap['volume'];
            if (level is num) {
              await setVolume(level.toInt());
            } else if (level is String) {
              final parsed = int.tryParse(level);
              if (parsed != null) await setVolume(parsed);
            }
            break;

          case 'toggle_flashlight':
            final state =
                paramMap['state'] ?? paramMap['enabled'] ?? paramMap['on'];
            if (state is bool) {
              await toggleFlashlight(state: state);
            } else if (state is String) {
              await toggleFlashlight(
                state:
                    state.toLowerCase() == 'true' ||
                    state == '1' ||
                    state == 'on',
              );
            } else {
              await toggleFlashlight();
            }
            break;

          case 'system_back':
          case 'back':
            await performBack();
            break;

          case 'system_home':
          case 'home':
            await performHome();
            break;

          case 'system_recents':
          case 'recents':
            await openRecents();
            break;

          case 'scroll_screen':
          case 'scroll_forward':
            await scrollForward();
            break;

          case 'click_screen_text':
          case 'click_text':
            final label =
                (paramMap['label'] ?? paramMap['text'] ?? '').toString();
            if (label.isNotEmpty) {
              await clickVisibleText(label);
            }
            break;

          case 'open_accessibility_settings':
            await openAccessibilitySettings();
            break;
        }
      }
    } catch (e) {
      AppLog.add('[Lỗi] handleIotPacket: $e');
    }
  }

  /// Loại bỏ các thẻ lệnh XML (`<MAP:...>`, `<BACK>`, v.v.) khỏi văn bản hiển thị giao diện
  static String stripTags(String rawText) {
    if (rawText.isEmpty) return rawText;
    return rawText
        .replaceAll(
          RegExp(
            r'<(?:MAP|YOUTUBE|APP|CALL|CLICK):\s*[^>]+>',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(r'<(?:BACK|HOME|RECENTS|SCROLL)>', caseSensitive: false),
          '',
        )
        .trim();
  }

  /// Chuẩn hoá câu lệnh tiếng Việt: loại bỏ kính ngữ / từ đệm ở đầu hoặc cuối câu
  static String normalizeCommand(String rawText) {
    String text = rawText.trim();
    // Bỏ các từ đệm/kính ngữ ở đầu câu (VD: "bạn ơi", "bạn", "ơi", "làm ơn", "hãy", "hãy giúp tôi", "giúp tôi", "xin hãy")
    text = text.replaceFirst(
      RegExp(
        r'^(?:bạn ơi|bạn|ơi|làm ơn|hãy|hãy giúp tôi|giúp tôi|giúp mình|hộ tôi|hộ mình|xin hãy)\s+',
        caseSensitive: false,
      ),
      '',
    );
    // Bỏ các từ đệm ở cuối câu (VD: "giúp tôi", "giúp mình", "giùm tôi", "nhé", "nha", "với", "đi", "đi bạn")
    text = text.replaceFirst(
      RegExp(
        r'\s+(?:giúp tôi|giúp mình|giùm tôi|giùm mình|hộ tôi|hộ mình|nhé|nha|với|đi|cho tôi|cho mình|được không|đi bạn|nhé bạn)$',
        caseSensitive: false,
      ),
      '',
    );
    return text.trim();
  }

  /// P0.2 - Bộ điều phối hành động bất đồng bộ có cấu trúc (Typed Async Action Dispatcher)
  /// Trả về kết quả thực thi [AssistantActionResult] nếu câu lệnh khớp một hành động,
  /// hoặc null nếu không phải lệnh điều khiển hệ thống/ứng dụng.
  static Future<AssistantActionResult?> dispatchCommand(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty) return null;

    // 1. Phân tích các thẻ nhúng hệ thống (<MAP:...>, <YOUTUBE:...>, <APP:...>, <BACK>, <HOME>, v.v.)
    final mapTag = RegExp(
      r'<MAP:\s*(.+?)>',
      caseSensitive: false,
    ).firstMatch(text);
    if (mapTag != null) {
      final dest = mapTag.group(1)?.trim() ?? '';
      AppLog.add('[INTENT] open_maps destination="$dest"');
      AppLog.add('[ACTION] method_channel_call');
      final res = await openGoogleMaps(dest.isNotEmpty ? dest : 'Google Maps');
      final bool success = res['success'] == true;
      AppLog.add('[ACTION] result success=$success');
      return AssistantActionResult(
        success: success,
        action: AssistantActionType.openMaps,
        message:
            success
                ? (dest.isNotEmpty
                    ? 'Đã mở Google Maps tìm $dest'
                    : 'Đã mở Google Maps')
                : 'Không thể mở Google Maps',
        data: Map<String, Object?>.from(res),
      );
    }

    final ytTag = RegExp(
      r'<YOUTUBE:\s*(.+?)>',
      caseSensitive: false,
    ).firstMatch(text);
    if (ytTag != null) {
      final query = ytTag.group(1)?.trim() ?? '';
      AppLog.add('[INTENT] open_youtube query="$query"');
      AppLog.add('[ACTION] method_channel_call');
      final res = await openYouTube(query.isNotEmpty ? query : 'YouTube');
      final bool success = res['success'] == true;
      AppLog.add('[ACTION] result success=$success');
      return AssistantActionResult(
        success: success,
        action: AssistantActionType.openYoutube,
        message:
            success
                ? (query.isNotEmpty
                    ? 'Đã mở YouTube tìm $query'
                    : 'Đã mở YouTube')
                : 'Không thể mở YouTube',
        data: Map<String, Object?>.from(res),
      );
    }

    final appTag = RegExp(
      r'<APP:\s*(.+?)>',
      caseSensitive: false,
    ).firstMatch(text);
    if (appTag != null) {
      final appName = appTag.group(1)?.trim() ?? '';
      AppLog.add('[INTENT] open_app app_name="$appName"');
      AppLog.add('[ACTION] method_channel_call');
      final res = await openApp(appName);
      final bool success = res['success'] == true;
      AppLog.add('[ACTION] result success=$success');
      return AssistantActionResult(
        success: success,
        action: AssistantActionType.openApp,
        message:
            success
                ? 'Đã mở ứng dụng $appName'
                : 'Không tìm thấy ứng dụng $appName trên thiết bị',
        data: Map<String, Object?>.from(res),
      );
    }

    if (RegExp(r'<BACK>', caseSensitive: false).hasMatch(text)) {
      AppLog.add('[INTENT] back');
      AppLog.add('[ACTION] method_channel_call');
      final success = await performBack();
      AppLog.add('[ACTION] result success=$success');
      return AssistantActionResult(
        success: success,
        action: AssistantActionType.back,
        message:
            success ? 'Đã thực hiện thao tác quay lại' : 'Không thể quay lại',
      );
    }

    if (RegExp(r'<HOME>', caseSensitive: false).hasMatch(text)) {
      AppLog.add('[INTENT] home');
      AppLog.add('[ACTION] method_channel_call');
      final success = await performHome();
      AppLog.add('[ACTION] result success=$success');
      return AssistantActionResult(
        success: success,
        action: AssistantActionType.home,
        message:
            success ? 'Đã về màn hình chính' : 'Không thể về màn hình chính',
      );
    }

    if (RegExp(r'<RECENTS>', caseSensitive: false).hasMatch(text)) {
      AppLog.add('[INTENT] recents');
      AppLog.add('[ACTION] method_channel_call');
      final success = await openRecents();
      AppLog.add('[ACTION] result success=$success');
      return AssistantActionResult(
        success: success,
        action: AssistantActionType.recents,
        message: success ? 'Đã mở màn hình đa nhiệm' : 'Không thể mở đa nhiệm',
      );
    }

    if (RegExp(r'<SCROLL>', caseSensitive: false).hasMatch(text)) {
      AppLog.add('[INTENT] scroll');
      AppLog.add('[ACTION] method_channel_call');
      final success = await scrollForward();
      AppLog.add('[ACTION] result success=$success');
      return AssistantActionResult(
        success: success,
        action: AssistantActionType.scroll,
        message: success ? 'Đã cuộn màn hình' : 'Không thể cuộn màn hình',
      );
    }

    final clickTag = RegExp(
      r'<CLICK:\s*(.+?)>',
      caseSensitive: false,
    ).firstMatch(text);
    if (clickTag != null) {
      final label = clickTag.group(1)?.trim() ?? '';
      AppLog.add('[INTENT] click_text label="$label"');
      AppLog.add('[ACTION] method_channel_call');
      final success = await clickVisibleText(label);
      AppLog.add('[ACTION] result success=$success');
      return AssistantActionResult(
        success: success,
        action: AssistantActionType.clickText,
        message:
            success
                ? 'Đã nhấn vào $label'
                : 'Không tìm thấy $label trên màn hình',
      );
    }

    // 2. Nhận diện ngôn ngữ tự nhiên tiếng Việt linh hoạt (đã loại bỏ kính ngữ / từ đệm)
    final cmd = normalizeCommand(text);

    // 2.1 Google Maps
    final mapsNlp = RegExp(
      r'^(?:chỉ đường|tìm đường|đường đi|dẫn đường|mở bản đồ|mở google maps?|mở gg maps?)\s*(?:đến|tới|đi|tại)?\s*(.*)$',
      caseSensitive: false,
    );
    final mapMatch = mapsNlp.firstMatch(cmd);
    if (mapMatch != null) {
      String dest = mapMatch.group(1)?.trim() ?? '';
      AppLog.add('[INTENT] open_maps destination="$dest"');
      AppLog.add('[ACTION] method_channel_call');
      final res = await openGoogleMaps(dest.isNotEmpty ? dest : 'Google Maps');
      final bool success = res['success'] == true;
      AppLog.add('[ACTION] result success=$success');
      return AssistantActionResult(
        success: success,
        action: AssistantActionType.openMaps,
        message:
            success
                ? (dest.isNotEmpty
                    ? 'Đã mở Google Maps tìm $dest'
                    : 'Đã mở Google Maps')
                : 'Không thể mở Google Maps',
        data: Map<String, Object?>.from(res),
      );
    }

    final nearbyMapsNlp = RegExp(
      r'^(?:tìm|kiếm)\s+(?:quán|cây xăng|tiệm|chỗ)?\s*(cà phê|cafe|cây xăng|quán ăn|nhà hàng|atm|bệnh viện|nhà thuốc)\s+(?:gần đây|gần đó|gần nhất)$',
      caseSensitive: false,
    );
    if (nearbyMapsNlp.hasMatch(cmd)) {
      AppLog.add('[INTENT] open_maps destination="$cmd"');
      AppLog.add('[ACTION] method_channel_call');
      final res = await openGoogleMaps(cmd);
      final bool success = res['success'] == true;
      AppLog.add('[ACTION] result success=$success');
      return AssistantActionResult(
        success: success,
        action: AssistantActionType.openMaps,
        message:
            success ? 'Đã mở Google Maps tìm $cmd' : 'Không thể mở Google Maps',
        data: Map<String, Object?>.from(res),
      );
    }

    // 2.2 YouTube
    final ytNlp = RegExp(
      r'^(?:mở youtube|bật nhạc|nghe bài|tìm trên youtube)\s*(.*)$',
      caseSensitive: false,
    );
    final ytMatch = ytNlp.firstMatch(cmd);
    if (ytMatch != null) {
      String query = ytMatch.group(1)?.trim() ?? '';
      if (query.toLowerCase().startsWith('tìm ')) {
        query = query.substring(4).trim();
      }
      AppLog.add('[INTENT] open_youtube query="$query"');
      AppLog.add('[ACTION] method_channel_call');
      final res = await openYouTube(query.isNotEmpty ? query : 'YouTube');
      final bool success = res['success'] == true;
      AppLog.add('[ACTION] result success=$success');
      return AssistantActionResult(
        success: success,
        action: AssistantActionType.openYoutube,
        message:
            success
                ? (query.isNotEmpty
                    ? 'Đã mở YouTube tìm $query'
                    : 'Đã mở YouTube')
                : 'Không thể mở YouTube',
        data: Map<String, Object?>.from(res),
      );
    }

    // 2.3 Đèn pin
    final flashNlp = RegExp(r'^(bật|tắt)\s+đèn pin$', caseSensitive: false);
    final flashMatch = flashNlp.firstMatch(cmd);
    if (flashMatch != null) {
      final state = flashMatch.group(1)?.toLowerCase() == 'bật';
      AppLog.add('[INTENT] toggle_flashlight state=$state');
      AppLog.add('[ACTION] method_channel_call');
      final res = await toggleFlashlight(state: state);
      final bool success = res['success'] == true;
      AppLog.add('[ACTION] result success=$success');
      return AssistantActionResult(
        success: success,
        action: AssistantActionType.toggleFlashlight,
        message:
            success
                ? (state ? 'Đã bật đèn pin' : 'Đã tắt đèn pin')
                : 'Không thể điều khiển đèn pin',
        data: Map<String, Object?>.from(res),
      );
    }

    // 2.4 Âm lượng
    if (RegExp(
      r'^(?:tăng|vặn to)\s+âm lượng$',
      caseSensitive: false,
    ).hasMatch(cmd)) {
      AppLog.add('[INTENT] adjust_volume up=true');
      AppLog.add('[ACTION] method_channel_call');
      final res = await adjustVolume(true);
      final bool success = res['success'] == true;
      AppLog.add('[ACTION] result success=$success');
      return AssistantActionResult(
        success: success,
        action: AssistantActionType.adjustVolume,
        message: success ? 'Đã tăng âm lượng' : 'Không thể tăng âm lượng',
        data: Map<String, Object?>.from(res),
      );
    }

    if (RegExp(
      r'^(?:giảm|vặn nhỏ)\s+âm lượng$',
      caseSensitive: false,
    ).hasMatch(cmd)) {
      AppLog.add('[INTENT] adjust_volume up=false');
      AppLog.add('[ACTION] method_channel_call');
      final res = await adjustVolume(false);
      final bool success = res['success'] == true;
      AppLog.add('[ACTION] result success=$success');
      return AssistantActionResult(
        success: success,
        action: AssistantActionType.adjustVolume,
        message: success ? 'Đã giảm âm lượng' : 'Không thể giảm âm lượng',
        data: Map<String, Object?>.from(res),
      );
    }

    final volSetNlp = RegExp(
      r'^(?:chỉnh|đặt|cài)\s+âm lượng\s+(\d+)$',
      caseSensitive: false,
    );
    final volSetMatch = volSetNlp.firstMatch(cmd);
    if (volSetMatch != null) {
      final level = int.tryParse(volSetMatch.group(1) ?? '') ?? 50;
      AppLog.add('[INTENT] set_volume level=$level');
      AppLog.add('[ACTION] method_channel_call');
      final res = await setVolume(level);
      final bool success = res['success'] == true;
      AppLog.add('[ACTION] result success=$success');
      return AssistantActionResult(
        success: success,
        action: AssistantActionType.setVolume,
        message:
            success ? 'Đã cài âm lượng về $level%' : 'Không thể cài âm lượng',
        data: Map<String, Object?>.from(res),
      );
    }

    // 2.5 Quay lại (BACK)
    if (RegExp(
      r'^(?:quay lại|trở lại|trở về|lùi lại|bấm back|ấn back)$',
      caseSensitive: false,
    ).hasMatch(cmd)) {
      AppLog.add('[INTENT] back');
      AppLog.add('[ACTION] method_channel_call');
      final success = await performBack();
      AppLog.add('[ACTION] result success=$success');
      return AssistantActionResult(
        success: success,
        action: AssistantActionType.back,
        message:
            success ? 'Đã thực hiện thao tác quay lại' : 'Không thể quay lại',
      );
    }

    // 2.6 Về màn hình chính (HOME) & Đóng ứng dụng (minh bạch giải thích)
    if (RegExp(
      r'^(?:về màn hình chính|về trang chủ|về home|màn hình chính|ra màn hình chính)$',
      caseSensitive: false,
    ).hasMatch(cmd)) {
      AppLog.add('[INTENT] home');
      AppLog.add('[ACTION] method_channel_call');
      final success = await performHome();
      AppLog.add('[ACTION] result success=$success');
      return AssistantActionResult(
        success: success,
        action: AssistantActionType.home,
        message:
            success ? 'Đã về màn hình chính' : 'Không thể về màn hình chính',
      );
    }

    if (RegExp(
      r'^(?:đóng|thoát)\s+(?:ứng dụng|app)?\s*(?:này|hiện tại)?$',
      caseSensitive: false,
    ).hasMatch(cmd)) {
      AppLog.add('[INTENT] close_app -> home');
      AppLog.add('[ACTION] method_channel_call');
      final success = await performHome();
      AppLog.add('[ACTION] result success=$success');
      return AssistantActionResult(
        success: success,
        action: AssistantActionType.home,
        message:
            success
                ? 'Đã thoát về màn hình chính (Android không cho phép đóng ứng dụng nền khác trực tiếp)'
                : 'Không thể thoát về màn hình chính',
      );
    }

    // 2.7 Mở đa nhiệm (RECENTS)
    if (RegExp(
      r'^(?:mở|xem)?\s*(?:đa nhiệm|ứng dụng gần đây|các app gần đây)$',
      caseSensitive: false,
    ).hasMatch(cmd)) {
      AppLog.add('[INTENT] recents');
      AppLog.add('[ACTION] method_channel_call');
      final success = await openRecents();
      AppLog.add('[ACTION] result success=$success');
      return AssistantActionResult(
        success: success,
        action: AssistantActionType.recents,
        message: success ? 'Đã mở màn hình đa nhiệm' : 'Không thể mở đa nhiệm',
      );
    }

    // 2.8 Cuộn trang (SCROLL)
    if (RegExp(
      r'^(?:cuộn|lướt|trượt)\s+(?:xuống|trang|tiếp)$',
      caseSensitive: false,
    ).hasMatch(cmd)) {
      AppLog.add('[INTENT] scroll');
      AppLog.add('[ACTION] method_channel_call');
      final success = await scrollForward();
      AppLog.add('[ACTION] result success=$success');
      return AssistantActionResult(
        success: success,
        action: AssistantActionType.scroll,
        message: success ? 'Đã cuộn màn hình' : 'Không thể cuộn màn hình',
      );
    }

    // 2.9 Nhấn văn bản trên màn hình (CLICK_TEXT)
    final clickNlp = RegExp(
      r'^(?:bấm|nhấn|chọn)\s+(?:vào|nút|chữ|mục)?\s*([a-zA-Z0-9\sÀ-ỹ]+)$',
      caseSensitive: false,
    );
    final clickMatch = clickNlp.firstMatch(cmd);
    if (clickMatch != null) {
      final label = clickMatch.group(1)?.trim() ?? '';
      if (label.isNotEmpty && label.length <= 40) {
        AppLog.add('[INTENT] click_text label="$label"');
        AppLog.add('[ACTION] method_channel_call');
        final success = await clickVisibleText(label);
        AppLog.add('[ACTION] result success=$success');
        return AssistantActionResult(
          success: success,
          action: AssistantActionType.clickText,
          message:
              success
                  ? 'Đã nhấn vào $label'
                  : 'Không tìm thấy $label trên màn hình',
        );
      }
    }

    // 2.10 Mở Cài đặt Trợ năng
    if (RegExp(
      r'^(?:mở|cài đặt)\s+trợ năng$',
      caseSensitive: false,
    ).hasMatch(cmd)) {
      AppLog.add('[INTENT] open_settings accessibility');
      AppLog.add('[ACTION] method_channel_call');
      await openAccessibilitySettings();
      AppLog.add('[ACTION] result success=true');
      return const AssistantActionResult(
        success: true,
        action: AssistantActionType.openSettings,
        message: 'Đã mở Cài đặt Trợ năng Android',
      );
    }

    // 2.11 Mở ứng dụng (OPEN_APP)
    final openAppNlp = RegExp(
      r'^(?:mở|chạy|bật)\s+(?:giúp tôi|giúp mình)?\s*(?:ứng dụng|app)?\s*([a-zA-Z0-9\sÀ-ỹ]+)$',
      caseSensitive: false,
    );
    final appMatch = openAppNlp.firstMatch(cmd);
    if (appMatch != null) {
      final app = appMatch.group(1)?.trim() ?? '';
      if (app.isNotEmpty) {
        final lower = app.toLowerCase();
        if (lower == 'youtube') {
          return dispatchCommand('mở youtube');
        }
        if (lower == 'bản đồ' ||
            lower == 'google map' ||
            lower == 'google maps' ||
            lower == 'gg map') {
          return dispatchCommand('mở google maps');
        }
        AppLog.add('[INTENT] open_app app_name="$app"');
        AppLog.add('[ACTION] method_channel_call');
        final res = await openApp(app);
        final bool success = res['success'] == true;
        AppLog.add('[ACTION] result success=$success');
        return AssistantActionResult(
          success: success,
          action: AssistantActionType.openApp,
          message:
              success
                  ? 'Đã mở ứng dụng $app'
                  : 'Không tìm thấy ứng dụng $app trên thiết bị',
          data: Map<String, Object?>.from(res),
        );
      }
    }

    return null;
  }

  /// Lớp tương thích: Phân tích và làm sạch thẻ tag (để hiển thị lên UI)
  /// Đồng thời thực thi nền nếu chưa qua dispatchCommand
  static String interceptAndExecute(String rawText) {
    if (rawText.isEmpty) return rawText;
    final clean = stripTags(rawText);

    // Kích hoạt dispatchCommand ngầm nếu chuỗi thô có thẻ hoặc khớp câu lệnh
    dispatchCommand(rawText);

    return clean;
  }
}
