import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/unsafe_ssl_helper.dart';

/// Kết quả kiểm tra phiên bản và kích hoạt OTA
class OtaCheckResult {
  final bool isActivated;
  final String? activationCode;
  final String? activationMessage;
  final String? activationChallenge;
  final int? timeoutMs;
  final String? websocketUrl;
  final String? websocketToken;

  OtaCheckResult({
    required this.isActivated,
    this.activationCode,
    this.activationMessage,
    this.activationChallenge,
    this.timeoutMs,
    this.websocketUrl,
    this.websocketToken,
  });

  bool get hasActivationCode =>
      activationCode != null && activationCode!.trim().isNotEmpty;
}

/// Kết quả hoàn tất kích hoạt (chứa URL và Token WebSocket)
class OtaActivationResult {
  final String websocketUrl;
  final String websocketToken;

  OtaActivationResult({
    required this.websocketUrl,
    required this.websocketToken,
  });
}

/// Token hủy luồng kích hoạt nền khi người dùng thoát màn hình
class OtaCancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

/// Dịch vụ kết nối OTA và kích hoạt thiết bị Xiaozhi (giả lập firmware ESP32)
class XiaozhiOtaService {
  static const String TAG = "XiaozhiOtaService";
  static const String defaultOtaUrl = "https://api.tenclass.net/xiaozhi/ota/";
  static const Duration requestTimeout = Duration(seconds: 15);

  final http.Client _client;

  XiaozhiOtaService({http.Client? client})
    : _client = client ?? UnsafeSslHelper.getUnsafeHttpClient();

  /// Chuẩn hóa URL OTA, luôn đảm bảo kết thúc bằng dấu gạch chéo '/'
  String _normalizeOtaUrl(String? url) {
    String clean =
        (url == null || url.trim().isEmpty) ? defaultOtaUrl : url.trim();
    if (!clean.endsWith('/')) {
      clean = '$clean/';
    }
    return clean;
  }

  /// Headers gửi lên server OTA
  Map<String, String> _buildHeaders({
    required String mac,
    required String clientId,
  }) {
    return {
      "Device-Id": mac.toLowerCase(),
      "Client-Id": clientId,
      "Content-Type": "application/json",
      "User-Agent": "hdvbot-android/1.0.0",
      "Accept-Language": "vi-VN",
    };
  }

  /// Body JSON giả lập cấu hình phần cứng thiết bị ESP32-S3
  Map<String, dynamic> _buildCheckVersionBody({
    required String mac,
    required String clientId,
  }) {
    final lowerMac = mac.toLowerCase();
    return {
      "version": 2,
      "language": "vi-VN",
      "flash_size": 16777216,
      "minimum_free_heap_size": 8318916,
      "mac_address": lowerMac,
      "uuid": clientId,
      "chip_model_name": "esp32s3",
      "chip_info": {"model": 9, "cores": 2, "revision": 2, "features": 18},
      "application": {
        "name": "xiaozhi",
        "version": "1.6.0",
        "compile_time": "Jan  1 2025T00:00:00Z",
        "idf_version": "v5.3.2",
        "elf_sha256":
            "0000000000000000000000000000000000000000000000000000000000000000",
      },
      "partition_table": [],
      "ota": {"label": "factory"},
      "board": {
        "type": "hdvbot-android",
        "name": "hdvbot-android",
        "ssid": "",
        "rssi": 0,
        "channel": 0,
        "ip": "",
        "mac": lowerMac,
      },
    };
  }

  /// Gửi yêu cầu checkVersion đến server OTA
  Future<OtaCheckResult> checkVersion({
    String? otaUrl,
    required String mac,
    required String clientId,
  }) async {
    final targetUrl = _normalizeOtaUrl(otaUrl);
    final headers = _buildHeaders(mac: mac, clientId: clientId);
    final bodyJson = jsonEncode(
      _buildCheckVersionBody(mac: mac, clientId: clientId),
    );

    print('$TAG: checkVersion -> $targetUrl (mac: $mac, client: $clientId)');

    http.Response response;
    try {
      response = await _client
          .post(Uri.parse(targetUrl), headers: headers, body: bodyJson)
          .timeout(requestTimeout);
    } catch (e) {
      print('$TAG: checkVersion lỗi mạng: $e');
      throw Exception('Không thể kết nối máy chủ OTA: $e');
    }

    if (response.statusCode != 200) {
      final preview =
          response.body.length > 200
              ? response.body.substring(0, 200)
              : response.body;
      print(
        '$TAG: checkVersion lỗi HTTP ${response.statusCode}, body: $preview',
      );
      throw Exception(
        'Lỗi máy chủ OTA (HTTP ${response.statusCode}): $preview',
      );
    }

    try {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final activation = data['activation'] as Map<String, dynamic>?;
      final websocket = data['websocket'] as Map<String, dynamic>?;

      final String? code = activation?['code']?.toString();
      final String? message = activation?['message']?.toString();
      final String? challenge = activation?['challenge']?.toString();
      final int? timeoutMs =
          activation?['timeout_ms'] is int
              ? activation!['timeout_ms'] as int
              : int.tryParse(activation?['timeout_ms']?.toString() ?? '');

      final String? wsUrl = websocket?['url']?.toString();
      final String? wsToken = websocket?['token']?.toString();

      final bool isActivated =
          (activation == null || code == null || code.trim().isEmpty);

      print(
        '$TAG: checkVersion thành công - isActivated: $isActivated, code: $code, wsUrl: $wsUrl',
      );

      return OtaCheckResult(
        isActivated: isActivated,
        activationCode: code,
        activationMessage: message,
        activationChallenge: challenge,
        timeoutMs: timeoutMs,
        websocketUrl: wsUrl,
        websocketToken: wsToken,
      );
    } catch (e) {
      if (e is FormatException) {
        throw Exception(
          'Dữ liệu phản hồi từ máy chủ OTA không đúng định dạng JSON',
        );
      }
      rethrow;
    }
  }

  /// Gửi yêu cầu kích hoạt activate lên server OTA
  /// HTTP 200 = đã kích hoạt thành công, 202 = đang chờ người dùng nhập mã, khác = lỗi
  Future<bool> activate({
    String? otaUrl,
    required String mac,
    required String clientId,
  }) async {
    final base = _normalizeOtaUrl(otaUrl);
    final targetUrl = '${base}activate';
    final headers = _buildHeaders(mac: mac, clientId: clientId);

    print('$TAG: activate -> $targetUrl');

    http.Response response;
    try {
      response = await _client
          .post(Uri.parse(targetUrl), headers: headers, body: '{}')
          .timeout(requestTimeout);
    } catch (e) {
      print('$TAG: activate lỗi mạng: $e');
      throw Exception('Không thể gửi yêu cầu kích hoạt: $e');
    }

    if (response.statusCode == 200) {
      print('$TAG: activate thành công (HTTP 200)');
      return true;
    } else if (response.statusCode == 202) {
      print('$TAG: activate đang chờ người dùng nhập mã (HTTP 202)');
      return false;
    } else {
      final preview =
          response.body.length > 200
              ? response.body.substring(0, 200)
              : response.body;
      print('$TAG: activate lỗi HTTP ${response.statusCode}: $preview');
      throw Exception('Lỗi kích hoạt (HTTP ${response.statusCode}): $preview');
    }
  }

  /// Điều phối quy trình kiểm tra và chờ kích hoạt OTA
  /// - Kiểm tra xem thiết bị đã kích hoạt chưa qua checkVersion.
  /// - Nếu có mã kích hoạt: thông báo qua callback onActivationCode và lặp gọi activate mỗi 3 giây.
  /// - Nếu trả về 202: tiếp tục chờ; nếu lỗi: đợi 10 giây; nếu hết timeout hoặc sau 10 lần: lấy lại mã mới.
  /// - Khi kích hoạt xong: gọi checkVersion lần nữa, trích xuất websocket url & token trả về.
  Future<OtaActivationResult> ensureActivated({
    String? otaUrl,
    required String mac,
    required String clientId,
    void Function(String code)? onActivationCode,
    void Function(String status)? onStatusChange,
    OtaCancellationToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled == true) {
      throw Exception('Đã hủy kích hoạt');
    }

    onStatusChange?.call('Đang kiểm tra trạng thái kích hoạt...');
    print('$TAG: ensureActivated bắt đầu');

    var checkResult = await checkVersion(
      otaUrl: otaUrl,
      mac: mac,
      clientId: clientId,
    );

    if (cancelToken?.isCancelled == true) {
      throw Exception('Đã hủy kích hoạt');
    }

    // Trường hợp 1: Thiết bị đã được kích hoạt từ trước
    if (checkResult.isActivated &&
        checkResult.websocketUrl != null &&
        checkResult.websocketUrl!.trim().isNotEmpty) {
      print('$TAG: Thiết bị đã được kích hoạt trước đó.');
      return OtaActivationResult(
        websocketUrl: checkResult.websocketUrl!,
        websocketToken: checkResult.websocketToken ?? '',
      );
    }

    // Trường hợp 2: Có mã kích hoạt, bắt đầu chu kỳ chờ người dùng nhập mã
    if (checkResult.hasActivationCode) {
      onActivationCode?.call(checkResult.activationCode!);
      onStatusChange?.call('Đang chờ kích hoạt...');
      print('$TAG: Mã kích hoạt thiết bị: ${checkResult.activationCode}');

      int pollCount = 0;
      DateTime startTime = DateTime.now();
      int timeoutMs = checkResult.timeoutMs ?? (5 * 60 * 1000);

      while (true) {
        if (cancelToken?.isCancelled == true) {
          throw Exception('Đã hủy kích hoạt');
        }

        // Chờ 3 giây trước lần kiểm tra tiếp theo
        await Future.delayed(const Duration(seconds: 3));

        if (cancelToken?.isCancelled == true) {
          throw Exception('Đã hủy kích hoạt');
        }

        try {
          final isDone = await activate(
            otaUrl: otaUrl,
            mac: mac,
            clientId: clientId,
          );

          if (isDone) {
            print('$TAG: activate báo thành công (HTTP 200)');
            break;
          }

          // Trả về HTTP 202: người dùng vẫn chưa nhập mã trên web
          pollCount++;
          print('$TAG: Đang chờ kích hoạt (lần $pollCount)...');

          final elapsed = DateTime.now().difference(startTime).inMilliseconds;
          if (elapsed >= timeoutMs || pollCount >= 10) {
            print(
              '$TAG: Đạt giới hạn poll ($pollCount) hoặc timeout ($elapsed ms), lấy mã mới...',
            );
            onStatusChange?.call('Đang lấy mã kích hoạt mới...');
            final newResult = await checkVersion(
              otaUrl: otaUrl,
              mac: mac,
              clientId: clientId,
            );

            if (newResult.isActivated) {
              checkResult = newResult;
              break;
            } else if (newResult.hasActivationCode) {
              checkResult = newResult;
              onActivationCode?.call(newResult.activationCode!);
              onStatusChange?.call('Đang chờ kích hoạt...');
              pollCount = 0;
              startTime = DateTime.now();
              timeoutMs = newResult.timeoutMs ?? (5 * 60 * 1000);
            }
          }
        } catch (e) {
          print('$TAG: activate gặp lỗi: $e. Chờ 10 giây thử lại...');
          onStatusChange?.call('Lỗi khi kích hoạt, thử lại sau 10 giây: $e');

          // Đợi 10 giây khi gặp lỗi mạng hoặc HTTP khác
          await Future.delayed(const Duration(seconds: 10));

          if (cancelToken?.isCancelled == true) {
            throw Exception('Đã hủy kích hoạt');
          }

          pollCount++;
          if (pollCount >= 10) {
            print('$TAG: Lấy lại mã kích hoạt mới sau chuỗi lỗi...');
            try {
              final newResult = await checkVersion(
                otaUrl: otaUrl,
                mac: mac,
                clientId: clientId,
              );
              if (newResult.isActivated) {
                checkResult = newResult;
                break;
              } else if (newResult.hasActivationCode) {
                checkResult = newResult;
                onActivationCode?.call(newResult.activationCode!);
                onStatusChange?.call('Đang chờ kích hoạt...');
                pollCount = 0;
                startTime = DateTime.now();
                timeoutMs = newResult.timeoutMs ?? (5 * 60 * 1000);
              }
            } catch (_) {}
          }
        }
      }
    }

    if (cancelToken?.isCancelled == true) {
      throw Exception('Đã hủy kích hoạt');
    }

    // Khi activate trả 200 hoặc checkVersion không còn activation:
    // Gọi checkVersion lần nữa để lấy websocket.url + websocket.token
    onStatusChange?.call('Đang tải cấu hình kết nối WebSocket...');
    print('$TAG: Gọi checkVersion lần cuối để lấy websocket config...');
    final finalResult = await checkVersion(
      otaUrl: otaUrl,
      mac: mac,
      clientId: clientId,
    );

    if (finalResult.websocketUrl == null ||
        finalResult.websocketUrl!.trim().isEmpty) {
      throw Exception(
        'Máy chủ chưa trả về địa chỉ WebSocket sau khi kích hoạt',
      );
    }

    print(
      '$TAG: Hoàn tất kích hoạt. WebSocket URL: ${finalResult.websocketUrl}',
    );
    return OtaActivationResult(
      websocketUrl: finalResult.websocketUrl!,
      websocketToken: finalResult.websocketToken ?? '',
    );
  }
}
