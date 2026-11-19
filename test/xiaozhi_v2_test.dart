import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_assistant/assistant_v2/assistant_mode.dart';
import 'package:ai_assistant/assistant_v2/assistant_v2_bridge.dart';
import 'package:ai_assistant/widgets/robot_face.dart';
import 'package:ai_assistant/services/assistant_action_executor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel systemActionChannel = MethodChannel(
    'com.lhht.ai_assistant/system_action',
  );
  const MethodChannel assistantV2Channel = MethodChannel(
    'com.lhht.ai_assistant/assistant_v2',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(systemActionChannel, (
          MethodCall methodCall,
        ) async {
          switch (methodCall.method) {
            case 'openMaps':
              final dest = methodCall.arguments['destination'] as String?;
              return {
                'success': true,
                'action': 'openMaps',
                'destination': dest,
              };
            case 'openYouTube':
              final query = methodCall.arguments['query'] as String?;
              return {'success': true, 'action': 'openYouTube', 'query': query};
            case 'openApp':
              final app = methodCall.arguments['appName'] as String?;
              return {'success': true, 'action': 'openApp', 'appName': app};
            case 'performBack':
              return true;
            case 'performHome':
              return true;
            case 'openRecents':
              return true;
            case 'scrollForward':
              return true;
            case 'clickVisibleText':
              return true;
            default:
              return null;
          }
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(assistantV2Channel, (
          MethodCall methodCall,
        ) async {
          switch (methodCall.method) {
            case 'beginConversation':
              return true;
            case 'endConversation':
              return true;
            case 'startWakeService':
              return true;
            case 'stopWakeService':
              return true;
            case 'accessibilityBack':
              return true;
            case 'accessibilityHome':
              return true;
            case 'accessibilityRecents':
              return true;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(systemActionChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(assistantV2Channel, null);
  });

  group('Xiaozhi 2.0 AssistantMode Tests', () {
    test('Correct wake phrase definition', () {
      expect(xiaozhiWakePhrase, equals('TinGTinG ơi'));
    });

    test('Maps native wire states to AssistantMode', () {
      expect(assistantModeFromNative('stopped'), equals(AssistantMode.stopped));
      expect(assistantModeFromNative('standby'), equals(AssistantMode.standby));
      expect(
        assistantModeFromNative('wake_detected'),
        equals(AssistantMode.wakeDetected),
      );
      expect(
        assistantModeFromNative('conversation'),
        equals(AssistantMode.conversation),
      );
      expect(
        assistantModeFromNative('executing'),
        equals(AssistantMode.executing),
      );
      expect(
        assistantModeFromNative('listening'),
        equals(AssistantMode.listening),
      );
      expect(
        assistantModeFromNative('thinking'),
        equals(AssistantMode.thinking),
      );
      expect(
        assistantModeFromNative('speaking'),
        equals(AssistantMode.speaking),
      );
      expect(assistantModeFromNative('error'), equals(AssistantMode.error));
      expect(
        assistantModeFromNative('unknown_value'),
        equals(AssistantMode.error),
      );
    });
  });

  group('Xiaozhi 2.0 Emotion Mapping Tests', () {
    test('Server emotion strings map to FaceEmotion correctly', () {
      expect(
        RobotFace.faceEmotionFromServer('happy'),
        equals(FaceEmotion.happy),
      );
      expect(RobotFace.faceEmotionFromServer('sad'), equals(FaceEmotion.sad));
      expect(
        RobotFace.faceEmotionFromServer('angry'),
        equals(FaceEmotion.angry),
      );
      expect(
        RobotFace.faceEmotionFromServer('laughing'),
        equals(FaceEmotion.laughing),
      );
      expect(
        RobotFace.faceEmotionFromServer('surprised'),
        equals(FaceEmotion.surprised),
      );
      expect(
        RobotFace.faceEmotionFromServer('sleepy'),
        equals(FaceEmotion.sleepy),
      );
      expect(
        RobotFace.faceEmotionFromServer('thinking'),
        equals(FaceEmotion.thinking),
      );
      expect(
        RobotFace.faceEmotionFromServer('neutral'),
        equals(FaceEmotion.neutral),
      );
      expect(
        RobotFace.faceEmotionFromServer(null),
        equals(FaceEmotion.neutral),
      );
    });
  });

  group('Xiaozhi 2.0 Action Engine Tag & NLP Tests', () {
    test('Tag extraction strips special tags from UI text', () {
      const raw = 'Dạ tôi đang mở bản đồ <MAP:Hồ Gươm Hà Nội> ngay đây ạ';
      final clean = AssistantActionExecutor.interceptAndExecute(raw);
      expect(clean, contains('Dạ tôi đang mở bản đồ'));
      expect(clean, isNot(contains('<MAP:')));
    });

    test('Tag extraction strips navigation tags', () {
      const raw = 'Đang quay lại màn hình trước <BACK>';
      final clean = AssistantActionExecutor.interceptAndExecute(raw);
      expect(clean, contains('Đang quay lại màn hình trước'));
      expect(clean, isNot(contains('<BACK>')));
    });

    test('IoT descriptor message structure is valid', () {
      final descriptor = AssistantActionExecutor.buildIotDescriptorMessage();
      expect(descriptor['type'], equals('iot'));
      final descriptors = descriptor['descriptors'] as List;
      final names = descriptors.map((d) => d['name']).toList();

      expect(names, contains('open_google_maps'));
      expect(names, contains('play_youtube'));
      expect(names, contains('open_app'));
      expect(names, contains('system_back'));
      expect(names, contains('system_home'));
      expect(names, contains('system_recents'));
      expect(names, contains('scroll_screen'));
      expect(names, contains('click_screen_text'));
      expect(names, contains('open_accessibility_settings'));
    });

    test(
      'normalizeCommand strips polite prefixes and conversational suffixes',
      () {
        expect(
          AssistantActionExecutor.normalizeCommand('bạn mở bản đồ giúp tôi'),
          equals('mở bản đồ'),
        );
        expect(
          AssistantActionExecutor.normalizeCommand(
            'bạn ơi mở youtube tìm nhạc trịnh nhé',
          ),
          equals('mở youtube tìm nhạc trịnh'),
        );
        expect(
          AssistantActionExecutor.normalizeCommand(
            'hãy mở youtube tìm nhạc trịnh',
          ),
          equals('mở youtube tìm nhạc trịnh'),
        );
        expect(
          AssistantActionExecutor.normalizeCommand('làm ơn quay lại nhé'),
          equals('quay lại'),
        );
        expect(
          AssistantActionExecutor.normalizeCommand('về trang chủ đi bạn'),
          equals('về trang chủ'),
        );
        expect(
          AssistantActionExecutor.normalizeCommand(
            'đóng ứng dụng này giúp tôi',
          ),
          equals('đóng ứng dụng này'),
        );
      },
    );

    test(
      'dispatchCommand handles conversational prefixes and suffixes',
      () async {
        // 1. Google Maps with prefix and suffix
        final mapRes = await AssistantActionExecutor.dispatchCommand(
          'bạn mở bản đồ giúp tôi',
        );
        expect(mapRes, isNotNull);
        expect(mapRes!.action, equals(AssistantActionType.openMaps));
        expect(mapRes.success, isTrue);

        // 2. YouTube search
        final ytRes = await AssistantActionExecutor.dispatchCommand(
          'hãy mở youtube tìm nhạc trịnh',
        );
        expect(ytRes, isNotNull);
        expect(ytRes!.action, equals(AssistantActionType.openYoutube));
        expect(ytRes.success, isTrue);

        // 3. Open App with infix "giúp tôi"
        final appRes = await AssistantActionExecutor.dispatchCommand(
          'mở giúp tôi ứng dụng zalo',
        );
        expect(appRes, isNotNull);
        expect(appRes!.action, equals(AssistantActionType.openApp));
        expect(appRes.success, isTrue);

        // 4. Back
        final backRes = await AssistantActionExecutor.dispatchCommand(
          'làm ơn quay lại nhé',
        );
        expect(backRes, isNotNull);
        expect(backRes!.action, equals(AssistantActionType.back));
        expect(backRes.success, isTrue);

        // 5. Home
        final homeRes = await AssistantActionExecutor.dispatchCommand(
          'về trang chủ đi bạn',
        );
        expect(homeRes, isNotNull);
        expect(homeRes!.action, equals(AssistantActionType.home));
        expect(homeRes.success, isTrue);

        // 6. Close app (clarified home fallback)
        final closeRes = await AssistantActionExecutor.dispatchCommand(
          'đóng ứng dụng này giúp tôi',
        );
        expect(closeRes, isNotNull);
        expect(closeRes!.action, equals(AssistantActionType.home));
        expect(closeRes.success, isTrue);
        expect(
          closeRes.message,
          contains('không cho phép đóng ứng dụng nền khác trực tiếp'),
        );
      },
    );

    test('Non-command query returns null from dispatchCommand', () async {
      final result = await AssistantActionExecutor.dispatchCommand(
        'Thời tiết hôm nay thế nào?',
      );
      expect(result, isNull);
    });

    test('AssistantActionType enum has all expected action variants', () {
      expect(
        AssistantActionType.values,
        contains(AssistantActionType.openMaps),
      );
      expect(
        AssistantActionType.values,
        contains(AssistantActionType.openYoutube),
      );
      expect(AssistantActionType.values, contains(AssistantActionType.openApp));
      expect(AssistantActionType.values, contains(AssistantActionType.back));
      expect(AssistantActionType.values, contains(AssistantActionType.home));
      expect(AssistantActionType.values, contains(AssistantActionType.recents));
      expect(AssistantActionType.values, contains(AssistantActionType.scroll));
      expect(
        AssistantActionType.values,
        contains(AssistantActionType.clickText),
      );
      expect(
        AssistantActionType.values,
        contains(AssistantActionType.setVolume),
      );
      expect(
        AssistantActionType.values,
        contains(AssistantActionType.adjustVolume),
      );
      expect(
        AssistantActionType.values,
        contains(AssistantActionType.toggleFlashlight),
      );
      expect(
        AssistantActionType.values,
        contains(AssistantActionType.openSettings),
      );
    });

    test('AssistantActionResult data model stores properties correctly', () {
      const res = AssistantActionResult(
        success: true,
        action: AssistantActionType.openMaps,
        message: 'Đã mở Google Maps tìm Hà Nội',
        data: {'target': 'Hà Nội'},
      );
      expect(res.success, isTrue);
      expect(res.action, equals(AssistantActionType.openMaps));
      expect(res.message, equals('Đã mở Google Maps tìm Hà Nội'));
      expect(res.data['target'], equals('Hà Nội'));
    });
  });

  group('Xiaozhi 2.0 Native Bridge 1:1 Ownership Tests', () {
    test(
      'AssistantV2Bridge calls beginConversation and endConversation',
      () async {
        final bridge = AssistantV2Bridge();
        final beginRes = await bridge.beginConversation();
        expect(beginRes, isTrue);

        final endRes = await bridge.endConversation();
        expect(endRes, isTrue);
      },
    );
  });
}
