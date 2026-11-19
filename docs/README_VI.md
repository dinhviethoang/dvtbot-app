# Xiaozhi 2.0 – gói mã nguồn bàn giao Antigravity

Gói này được chuẩn bị dựa trên repository `dinhviethoang/dvtbot-app`, nhánh mặc định `main`,
package Android `com.king.hdvbot`, Kotlin namespace `com.lhht.ai_assistant`.

## Mục tiêu đã chốt

- Wake phrase: **“TinGTinG ơi”**.
- Chờ wake phrase trong trạng thái nền; sau khi đánh thức thì trò chuyện và thực thi nhiều lệnh liên tiếp.
- Khi mở Google Maps hoặc ứng dụng khác, không được để Flutter Activity tự hủy phiên.
- Có Accessibility Service để thao tác giao diện sau khi người dùng tự bật quyền.
- UI: nền đen, chỉ mắt và miệng robot; tái sử dụng `RobotFace`, `FaceEmotion` và cảm xúc hiện có.
- Giữ nguyên OTA, WebSocket, STT, TTS, Opus, session ID và chức năng cũ.

## Cấu trúc gói

- `android/.../AssistantV2Contract.kt`: hợp đồng trạng thái dùng chung.
- `android/.../WakeWordEngine.kt`: giao diện engine wake word cục bộ.
- `android/.../WakeWordForegroundService.kt`: foreground service microphone, notification và state machine.
- `android/.../XiaozhiAccessibilityService.kt`: Accessibility Service mẫu, có giới hạn an toàn.
- `android/AndroidManifest_additions.xml`: các khai báo cần merge vào Manifest hiện có.
- `android/gradle_additions.gradle.kts`: phần dependency/cấu hình cần xem xét.
- `lib/assistant_v2/assistant_mode.dart`: state model Dart cho UI và phiên hội thoại.
- `docs/PROMPT_ANTIGRAVITY.md`: prompt giao việc chi tiết.
- `docs/INTEGRATION_NOTES.md`: các điểm phải tích hợp với code hiện có.

## Rất quan trọng – giới hạn hiện tại của gói

Gói này là **starter implementation có mã nền và hợp đồng tích hợp**, không phải APK hoàn chỉnh.
Wake-word engine cần một model offline tương thích với câu “TinGTinG ơi”. Model không được bịa hoặc giả lập:
`WakeWordEngine` là adapter interface; Antigravity phải tích hợp model thật, kiểm thử false-positive/false-negative
và chỉ khi model được nạp thành công mới cho phép hiển thị trạng thái “Wake word ready”.

Không dùng đo âm lượng làm wake word. Code hiện tại trong `VoiceCallScreen` có cơ chế phát hiện âm lượng vượt ngưỡng;
cơ chế đó chỉ phát hiện tiếng động, không nhận diện câu “TinGTinG ơi”.

Không được tuyên bố “luôn nghe khi tắt màn hình” trên mọi thiết bị. Android có giới hạn foreground microphone service,
quyền runtime, chính sách OEM và battery optimization. Phải khởi động service từ trạng thái hợp lệ khi Activity đang hiển thị,
hiển thị notification và cho người dùng nút dừng.

## Cách dùng

1. Giải nén gói.
2. Mở repository gốc trong Antigravity.
3. Đưa `docs/PROMPT_ANTIGRAVITY.md` cho Antigravity cùng toàn bộ gói này.
4. Yêu cầu Antigravity đọc code hiện tại trước, sau đó merge từng file; không ghi đè `MainActivity.kt`,
   `AndroidManifest.xml`, `VoiceCallScreen` hoặc `XiaozhiService` một cách mù quáng.
5. Yêu cầu build và test sau từng giai đoạn.

Bridge Native/Dart đã có trong gói: `AssistantV2Channels.kt` và `assistant_v2_bridge.dart`.
Trong `MainActivity.configureFlutterEngine`, gọi `AssistantV2Channels.register(this, flutterEngine)` sau `super.configureFlutterEngine(flutterEngine)`; giữ nguyên channel `system_action` cũ.
