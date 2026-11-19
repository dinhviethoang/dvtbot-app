import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:ai_assistant/providers/config_provider.dart';
import 'package:ai_assistant/providers/conversation_provider.dart';
import 'package:ai_assistant/screens/home_screen.dart';
import 'package:ai_assistant/utils/app_theme.dart';
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'package:opus_dart/opus_dart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:ui';
import 'package:ai_assistant/utils/audio_util.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:ai_assistant/utils/unsafe_ssl_helper.dart';

void main() async {
  // Bỏ qua lỗi chứng chỉ SSL Let's Encrypt trên Android 7.1.1 (Samsung Galaxy J2 Pro)
  UnsafeSslHelper.init();
  WidgetsFlutterBinding.ensureInitialized();

  // Thiết lập giao diện hệ thống
  await _setupSystemUI();

  SystemChannels.lifecycle.setMessageHandler((msg) async {
    if (msg == AppLifecycleState.resumed.toString()) {
      await _setupSystemUI();
    }
    return null;
  });

  if (Platform.isAndroid || Platform.isIOS) {
    await Future.delayed(const Duration(milliseconds: 50));
    PaintingBinding.instance.imageCache.maximumSize = 1000;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024;
  }

  // Yêu cầu quyền microphone và bộ nhớ
  await [
    Permission.microphone,
    Permission.storage,
    if (Platform.isAndroid) Permission.bluetoothConnect,
  ].request();

  // Thiết lập ngôn ngữ tiếng Việt cho timeago
  timeago.setLocaleMessages('vi', timeago.ViMessages());
  timeago.setDefaultLocale('vi');

  // Cấu hình tần số quét cao trên Android
  if (Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e) {
      print('Thiết lập tần số quét thất bại: $e');
    }
  }

  // Khởi tạo thư viện Opus
  try {
    initOpus(await opus_flutter.load());
    print('Khởi tạo Opus thành công: ${getOpusVersion()}');
  } catch (e) {
    print('Khởi tạo Opus thất bại: $e');
  }

  // Khởi tạo hệ thống âm thanh
  try {
    await AudioUtil.initRecorder();
    await AudioUtil.initPlayer();
    print('Khởi tạo hệ thống âm thanh thành công');
  } catch (e) {
    print('Khởi tạo hệ thống âm thanh thất bại: $e');
  }

  // Khởi tạo cấu hình và hội thoại
  final configProvider = ConfigProvider();
  await configProvider.loadConfigs();
  final conversationProvider = ConversationProvider();
  await conversationProvider.loadConversations();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: configProvider),
        ChangeNotifierProvider.value(value: conversationProvider),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> _setupSystemUI() async {
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

  if (Platform.isAndroid) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } else if (Platform.isIOS) {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top],
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'botAi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown,
        },
      ),
    );
  }
}
