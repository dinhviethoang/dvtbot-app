import 'dart:convert';
import 'package:flutter/services.dart';
import '../utils/app_log.dart';

/// Bộ thực thi lệnh hệ thống (System Assistant Action Engine)
/// Điều khiển điện thoại Android như Google Assistant thông qua Intent & MethodChannel
class AssistantActionExecutor {
  static const MethodChannel _channel = MethodChannel(
    'com.lhht.ai_assistant/system_action',
  );

  static bool _flashlightState = false;

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
        }
      }
    } catch (e) {
      AppLog.add('[Lỗi] handleIotPacket: $e');
    }
  }

  /// Lớp 2: Phân tích ngữ nghĩa kép (Tag Parser & Vietnamese Natural Language Trigger)
  /// Trả về chuỗi văn bản đã loại bỏ thẻ tag (để hiển thị lên UI)
  static String interceptAndExecute(String rawText) {
    if (rawText.isEmpty) return rawText;
    String cleanText = rawText;

    // --- RULE A: Tag Parser (<MAP:...>, <YOUTUBE:...>, <APP:...>, <CALL:...>) ---
    final mapRegex = RegExp(r'<MAP:\s*(.+?)>', caseSensitive: false);
    for (final match in mapRegex.allMatches(rawText)) {
      final dest = match.group(1)?.trim();
      if (dest != null && dest.isNotEmpty) {
        openGoogleMaps(dest);
      }
    }
    cleanText = cleanText.replaceAll(mapRegex, '');

    final ytRegex = RegExp(r'<YOUTUBE:\s*(.+?)>', caseSensitive: false);
    for (final match in ytRegex.allMatches(rawText)) {
      final query = match.group(1)?.trim();
      if (query != null && query.isNotEmpty) {
        openYouTube(query);
      }
    }
    cleanText = cleanText.replaceAll(ytRegex, '');

    final appRegex = RegExp(r'<APP:\s*(.+?)>', caseSensitive: false);
    for (final match in appRegex.allMatches(rawText)) {
      final appName = match.group(1)?.trim();
      if (appName != null && appName.isNotEmpty) {
        openApp(appName);
      }
    }
    cleanText = cleanText.replaceAll(appRegex, '');

    final callRegex = RegExp(r'<CALL:\s*(.+?)>', caseSensitive: false);
    for (final match in callRegex.allMatches(rawText)) {
      final number = match.group(1)?.trim();
      if (number != null && number.isNotEmpty) {
        makePhoneCall(number);
      }
    }
    cleanText = cleanText.replaceAll(callRegex, '');

    // --- RULE B: Vietnamese Natural Language Trigger ---
    final textForMatching = rawText.trim();

    // 1. Google Maps: "chỉ đường đến...", "tìm đường đi..."
    final mapsNlp = RegExp(
      r'(?:chỉ đường|tìm đường|đường đi|dẫn đường|mở bản đồ|mở google map|mở gg map)\s+(?:đến|tới|đi|tại)?\s*(.+)',
      caseSensitive: false,
    );
    final mapMatch = mapsNlp.firstMatch(textForMatching);
    if (mapMatch != null) {
      final dest = mapMatch.group(1)?.trim();
      if (dest != null && dest.isNotEmpty && !dest.startsWith('<')) {
        openGoogleMaps(dest);
        return cleanText.trim();
      }
    }

    // 2. YouTube: "mở youtube...", "bật nhạc..."
    final ytNlp = RegExp(
      r'(?:mở youtube|bật nhạc|nghe bài|tìm trên youtube)\s+(.+)',
      caseSensitive: false,
    );
    final ytMatch = ytNlp.firstMatch(textForMatching);
    if (ytMatch != null) {
      final query = ytMatch.group(1)?.trim();
      if (query != null && query.isNotEmpty && !query.startsWith('<')) {
        openYouTube(query);
        return cleanText.trim();
      }
    }

    // 3. Đèn pin: "bật đèn pin", "tắt đèn pin"
    final flashNlp = RegExp(r'(bật|tắt)\s+đèn pin', caseSensitive: false);
    final flashMatch = flashNlp.firstMatch(textForMatching);
    if (flashMatch != null) {
      final action = flashMatch.group(1)?.toLowerCase();
      toggleFlashlight(state: action == 'bật');
      return cleanText.trim();
    }

    // 4. Âm lượng: "tăng âm lượng", "giảm âm lượng", "chỉnh âm lượng 80"
    final volUpNlp = RegExp(
      r'(?:tăng|vặn to)\s+âm lượng',
      caseSensitive: false,
    );
    if (volUpNlp.hasMatch(textForMatching)) {
      adjustVolume(true);
      return cleanText.trim();
    }

    final volDownNlp = RegExp(
      r'(?:giảm|vặn nhỏ)\s+âm lượng',
      caseSensitive: false,
    );
    if (volDownNlp.hasMatch(textForMatching)) {
      adjustVolume(false);
      return cleanText.trim();
    }

    final volSetNlp = RegExp(
      r'(?:chỉnh|đặt|cài)\s+âm lượng\s+(\d+)',
      caseSensitive: false,
    );
    final volSetMatch = volSetNlp.firstMatch(textForMatching);
    if (volSetMatch != null) {
      final level = int.tryParse(volSetMatch.group(1) ?? '');
      if (level != null) {
        setVolume(level);
        return cleanText.trim();
      }
    }

    // 5. Mở ứng dụng: "mở zalo", "mở camera", v.v.
    final openAppNlp = RegExp(
      r'(?:mở|chạy|bật)\s+(?:ứng dụng|app)?\s*(zalo|chrome|cài đặt|camera|facebook|fb|messenger|tiktok|tin nhắn|danh bạ|youtube|bản đồ)',
      caseSensitive: false,
    );
    final openAppMatch = openAppNlp.firstMatch(textForMatching);
    if (openAppMatch != null) {
      final app = openAppMatch.group(1)?.trim();
      if (app != null && app.isNotEmpty) {
        openApp(app);
        return cleanText.trim();
      }
    }

    return cleanText.trim();
  }
}
