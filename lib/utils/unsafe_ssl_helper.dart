import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Module bỏ qua kiểm tra chứng chỉ SSL/TLS cho Android 7.1.1 (Samsung Galaxy J2 Pro)
/// và các thiết bị có chứng chỉ gốc Let's Encrypt đã hết hạn.
class UnsafeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Chấp nhận mọi chứng chỉ SSL/TLS (kể cả chứng chỉ đã hết hạn trên OS cũ)
        return true;
      };
  }
}

class UnsafeSslHelper {
  static bool _initialized = false;
  static http.Client? _cachedClient;

  /// Kích hoạt bỏ qua xác thực SSL trên toàn bộ ứng dụng Dart/Flutter
  static void init() {
    if (_initialized) return;
    try {
      HttpOverrides.global = UnsafeHttpOverrides();
      _initialized = true;
      print(
        'UnsafeSslHelper: Đã kích hoạt UnsafeHttpOverrides.global thành công',
      );
    } catch (e) {
      print('UnsafeSslHelper: Lỗi khi thiết lập HttpOverrides: $e');
    }
  }

  /// Trả về một dart:io HttpClient chấp nhận mọi chứng chỉ
  static HttpClient getUnsafeIoHttpClient() {
    final client = HttpClient();
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    client.connectionTimeout = const Duration(seconds: 15);
    return client;
  }

  /// Trả về một http.Client (IOClient) cho các thư viện HTTP sử dụng
  static http.Client getUnsafeHttpClient() {
    _cachedClient ??= IOClient(getUnsafeIoHttpClient());
    return _cachedClient!;
  }
}
