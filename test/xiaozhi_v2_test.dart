import 'package:flutter_test/flutter_test.dart';
import 'package:ai_assistant/assistant_v2/assistant_mode.dart';
import 'package:ai_assistant/widgets/robot_face.dart';
import 'package:ai_assistant/services/assistant_action_executor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
  });
}
