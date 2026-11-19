# Integration notes – đọc trước khi sửa code

## Đã xác minh trong repository `main`

- `pubspec.yaml`: Flutter SDK constraint `^3.7.0`; đã có `provider`, `shared_preferences`,
  `permission_handler`, `record`, `flutter_sound`, `audio_session`, `web_socket_channel`,
  `opus_flutter`, `opus_dart`.
- Android namespace: `com.lhht.ai_assistant`.
- Application ID: `com.king.hdvbot`.
- Kotlin source package hiện dùng `com.lhht.ai_assistant`.
- `MainActivity.kt` đã có MethodChannel `com.lhht.ai_assistant/system_action`,
  xử lý `openGoogleMaps`, `openYouTube`, `openApp`, volume, flashlight và FloatingAvatar.
- `FloatingAvatarService.kt` hiện chỉ vẽ bubble nổi; KHÔNG phải audio service.
- `VoiceCallScreen` đã có `XiaozhiService`, OTA, emotion notifier, `RobotFace` và `botai_robot_avatar`.
- `VoiceCallScreen` hiện có `_startLocalWakeMonitoring()` dựa trên amplitude threshold.
  Đây không phải keyword spotting. Thay bằng local model detector, không giữ cả hai recorder.
- `XiaozhiService` quản lý WebSocket, session, Opus và AudioUtil. Không tạo một XiaozhiService
  thứ hai trong Android Service.

## Việc Antigravity phải làm

1. Đọc toàn bộ `VoiceCallScreen`, `XiaozhiService`, `XiaozhiWebSocketManager`,
   `AudioUtil`, `MainActivity`, `AssistantActionExecutor`, `RobotFace`.
2. Thiết kế một AudioSessionOwner duy nhất. Chọn rõ ràng ai đang sở hữu microphone:
   - STANDBY: native WakeWordForegroundService sở hữu AudioRecord.
   - CONVERSATION: dừng/release AudioRecord của wake detector rồi chuyển quyền thu âm cho
     pipeline Xiaozhi hiện có; hoặc triển khai một AudioRecord duy nhất và chia frame cho cả
     wake detector/STT. Không mở hai recorder cùng lúc.
   - Kết thúc hội thoại: dừng recorder hội thoại, khởi động lại wake detector.
3. Khi mở Google Maps, Flutter Activity có thể pause/stop nhưng không được gọi disconnect
   hoặc dispose XiaozhiService chỉ vì lifecycle pause.
4. Tách lifetime của session khỏi lifetime của VoiceCallScreen. Service/manager phải tồn tại
   độc lập; UI chỉ subscribe trạng thái.
5. Khi nhận broadcast `wake_detected`, Flutter phải bắt đầu/reuse session hiện tại và chuyển
   sang conversation mode. Không khởi tạo thêm socket/session nếu đã có.
6. Thêm event bridge Native -> Flutter (EventChannel hoặc BroadcastReceiver + EventChannel).
7. Chỉ khi người dùng bấm “Kết thúc phiên”, nói “Tạm biệt/Ngủ đi”, hoặc idle timeout mới
   kết thúc hội thoại và quay về wake standby.
8. Thêm Accessibility settings entry để người dùng tự bật service. Không tự bật quyền.
9. Chỉ thêm các action allow-list: BACK, HOME, RECENTS, click visible text, scroll.
   Yêu cầu xác nhận trước thao tác có hậu quả như gửi tin, xóa dữ liệu, thanh toán, đăng bài.
10. Xem lại `QUERY_ALL_PACKAGES`: chỉ giữ nếu cần và đáp ứng chính sách phân phối; ưu tiên
    package visibility queries cụ thể.
11. Bỏ yêu cầu Overlay permission tự động nếu không cần floating avatar. Không yêu cầu quyền
    không liên quan tới tính năng đã bật.
12. Không log token, transcript nhạy cảm, nội dung màn hình hoặc audio thô.

## UI

- Màn hình chính đen tuyệt đối.
- Chỉ hiển thị hai mắt và miệng robot ở trung tâm.
- Tái sử dụng `RobotFace`, `FaceEmotion`, `EmotionDetector`.
- Giữ các trạng thái hiện có và thêm trạng thái `standby`, `wakeDetected`, `executing`.
- Không render chat bubbles hoặc transcript trên màn hình chính.
- Giữ controls nhỏ: microphone privacy toggle, settings, end session.
- Khi TTS phát, tiếp tục dùng volume/amplitude để animate miệng, không tạo animation độc lập không đồng bộ.

## Kiểm thử

- Wake phrase chính xác “TinGTinG ơi”; kiểm tra tiếng Việt, giọng khác nhau, TV/âm nhạc nền.
- Không được wake vì tiếng động lớn.
- Wake -> conversation -> mở Maps -> nói tiếp -> tool -> nói tiếp -> end -> standby.
- Kiểm tra Android 13, 14, 15/16 tùy thiết bị.
- Kiểm tra quyền notification, microphone, accessibility và battery optimization.
- Kiểm tra cuộc gọi điện thoại, tai nghe Bluetooth, audio focus, mic bị app khác chiếm.
- Kiểm tra process kill/reboot: không tự bật mic trái phép; hướng dẫn người dùng mở app để kích hoạt lại nếu Android không cho phép.

## Native/Dart bridge trong gói

- Thêm `AssistantV2Channels.register(this, flutterEngine)` vào `MainActivity.configureFlutterEngine`.
- Đưa `android/app/src/main/res/xml/xiaozhi_accessibility_service.xml` và `values/xiaozhi_strings.xml` vào đúng resource folders.
- Thêm `assistant_v2_bridge.dart` vào Provider/service locator cấp ứng dụng; không tạo bridge trong Widget ngắn hạn.
- Khi `wake_detected`, chuyển ownership microphone trước khi gọi `XiaozhiService.startListeningCall()`.
