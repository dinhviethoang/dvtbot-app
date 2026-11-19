# XIAOZHI 2.0 – BUG REPORT & REPAIR PLAN (DỰA TRÊN SOURCE THỰC TẾ)

Repository: `dinhviethoang/dvtbot-app`
Branch đã đối chiếu: `main`
Android namespace: `com.lhht.ai_assistant`
Application ID: `com.king.hdvbot`
Wake phrase mong muốn: **“TinGTinG ơi”**

Đây là bản sửa lỗi cho các triệu chứng đã quan sát trên APK. Không tạo project mới, không tiếp tục thêm tính năng mới trước khi sửa xong các lỗi P0 bên dưới.

## A. BUG ĐÃ XÁC MINH TRONG SOURCE `main`

### BUG 1 – Wake word hiện không tồn tại

File: `lib/screens/voice_call_screen.dart`

Hàm `_startLocalWakeMonitoring()` hiện:
- lấy `voice_wake_threshold`, mặc định `0.0316`;
- đọc `AudioUtil.amplitudeStream`;
- nếu âm lượng vượt ngưỡng trong ít nhất 300 ms thì gọi `_wakeUp(...)`.

Đây chỉ là phát hiện tiếng động/âm lượng, KHÔNG phải nhận diện câu “TinGTinG ơi”.
Nó có thể bị kích hoạt bởi tiếng TV, nhạc, tiếng nói bất kỳ hoặc không kích hoạt nếu recorder không còn chạy.
Không được mô tả chức năng này là wake-word detection.

### BUG 2 – Lệnh ngủ ngắt server nhưng không có bộ đánh thức thật

File: `lib/screens/voice_call_screen.dart`

`_goToSleep()` gọi:
`await _xiaozhiService?.disconnect();`

Sau đó mới gọi `_startLocalWakeMonitoring()`. Bộ monitor chỉ đo âm lượng như BUG 1.
Khi có trigger, `_wakeUp()` lại:
- gọi `switchToVoiceCallMode()`;
- `clearSessionId()`;
- `connect()`;
- chờ `hello` tối đa 8 giây;
- rồi `startListeningCall()`.

Nếu local monitor không nhận được sự kiện, không có đường đánh thức. Đặc biệt khi `VoiceCallScreen` bị dispose hoặc Activity bị hệ thống kill, logic theo Timer/Stream của Widget cũng không còn là một nền tảng wake service bền vững.

Ngoài ra `_resetSilenceTimer()` tự đưa phiên về sleep sau 20 giây không có âm thanh.
Không được bỏ timeout mà không có thiết kế standby thay thế; nhưng khi vào standby, phải bàn giao microphone cho một local wake engine thật.

### BUG 3 – Action chạy nhưng AI vẫn nói không làm được

Files:
- `lib/services/assistant_action_executor.dart`
- `lib/services/xiaozhi_service.dart`

`AssistantActionExecutor.interceptAndExecute(String rawText)` trả về `String` đồng bộ.
Bên trong, hàm gọi các hàm bất đồng bộ như `openGoogleMaps()`, `openYouTube()`, `openApp()` nhưng không `await` chúng và không trả kết quả thực thi có cấu trúc.

`XiaozhiService.sendTextMessage()` gọi:
`AssistantActionExecutor.interceptAndExecute(message);`

Sau đó vẫn tiếp tục gửi nguyên văn nội dung:
`_webSocketManager!.sendTextRequest(message);`

Do đó một yêu cầu có thể:
1. kích hoạt action cục bộ;
2. vẫn gửi nguyên lệnh lên AI server;
3. server trả lời theo kiến thức/ngữ cảnh của nó và nói không thể thực hiện.

Đây là nguyên nhân trực tiếp có thể giải thích triệu chứng “Maps đã mở nhưng AI nói không mở được”. Không được chỉ sửa system prompt.

Quan trọng: trong voice mode, audio được gửi qua `startListeningCall()` và `AudioUtil.audioStream`; không được giả định hàm `sendTextMessage()` tự xử lý hết câu lệnh thoại. Phải kiểm tra cả đường đi `type == 'stt'` và luồng tool response của server.

### BUG 4 – Thiếu lệnh đóng/thoát app có định nghĩa rõ

File Kotlin `AssistantActionExecutor.kt` có `openGoogleMaps`, `openYouTube`, `openApp`.
MainActivity hiện map các method `openGoogleMaps`, `openYouTube`, `openApp`... nhưng không có method tổng quát `closeApp` tương ứng.

Phải phân biệt:
- `BACK`: điều hướng quay lại trong app hiện tại.
- `HOME`: đưa launcher ra foreground.
- `RECENTS`: mở màn hình ứng dụng gần đây.
- `DISMISS_RECENT_TASK`: chỉ triển khai gesture vuốt thẻ app trong Recents khi kiểm thử Accessibility và thiết bị cho phép.

Android app thông thường không thể force-stop tùy tiện app khác. Không được báo “đã force close” nếu chỉ thực hiện HOME/BACK.

### BUG 5 – Emotion state không phải lúc nào cũng làm UI rebuild

Files:
- `lib/screens/voice_call_screen.dart`
- `lib/widgets/botai_robot_avatar.dart`
- `lib/widgets/robot_face.dart`
- `lib/utils/emotion_detector.dart`

Widget `BotAiRobotAvatar` có `didUpdateWidget()` và nội suy pose theo `FaceEmotion`/`FaceState`.
`VoiceCallScreen._onRobotSentence()` cũng gọi `setState()`.

Tuy nhiên trong `_handleServerMessage()`, khi gói message có trường `emotion`, code gán trực tiếp:
`_currentEmotion = _resolveEmotion(emotion);`
mà không gọi `setState()` ngay tại nhánh đó. Nếu emotion đến trong message riêng, widget có thể không vẽ lại cho tới một state update khác.

Bên cạnh đó, detector chỉ khớp từ khóa và emoji trong một danh sách cố định. Câu nói không có từ khóa sẽ về neutral, dù giọng điệu có cảm xúc.

---

## B. THỨ TỰ SỬA – BẮT BUỘC THEO P0 → P1 → P2

# P0 – PHẢI SỬA TRƯỚC

### P0.1 – Xây dựng một Emotion Pipeline duy nhất

Tạo helper `_applyEmotion(FaceEmotion emotion, {required String source})` trong VoiceCallScreen:
- kiểm tra `mounted`;
- gọi `setState` khi giá trị thay đổi;
- ghi log source, state, emotion;
- không cập nhật `_currentEmotion` rải rác ở nhiều nơi.

Dùng helper cho:
- emotion field trong mọi server packet;
- emotionNotifier;
- từng TTS sentence_start;
- fallback EmotionDetector;
- state transitions như listening/thinking/speaking/sleepy.

Quy tắc ưu tiên:
1. emotion cụ thể do server gửi;
2. nếu server không gửi emotion thì detect câu TTS;
3. nếu không đủ tín hiệu thì giữ neutral, không chọn ngẫu nhiên.

Kiểm tra `_BotAiFacePose.fromState()` có pose khác nhau thật cho từng emotion và các pose không quá giống nhau.
Thêm debug UI tạm thời trong build Debug: hiển thị nhỏ `FaceState / FaceEmotion`; loại khỏi Release.
Không để shell artwork có sẵn mắt/miệng chồng với face painter. Kiểm tra asset shell thật.

### P0.2 – Sửa Action Dispatcher để action có kết quả thật

Thay thiết kế fire-and-forget bằng typed async dispatcher.

Ví dụ contract mong muốn:

```dart
enum AssistantActionType {
  openMaps,
  openYoutube,
  openApp,
  back,
  home,
  recents,
}

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
}
```

Dispatcher phải:
- parse command;
- gọi đúng Android MethodChannel;
- `await` kết quả;
- xác nhận success/failure từ Kotlin;
- chỉ phản hồi “đã mở” sau khi MethodChannel trả `success=true`;
- không gửi lại cùng lệnh như một câu hỏi thông thường cho LLM sau khi local action đã được thực thi;
- đưa action result vào conversation UI/history theo cách có thể phân biệt với câu trả lời LLM.

Không được để cùng một câu lệnh bị execute hai lần (một lần local, một lần do server tool tag).

### P0.3 – Nối đường thoại thật vào Action Dispatcher

Voice flow hiện gửi audio frames đến Xiaozhi server. Phải xác minh giao thức:
- Khi server gửi `type: stt`, đây là transcript người dùng.
- Xác minh server có phát tiếp LLM/TTS tự động sau sự kiện STT không.
- Xác minh có giao thức tool/function call hoặc action-result callback chính thức không.

Chọn một thiết kế thống nhất:

**Ưu tiên A – Server tool calling:** AI server trả về action/function call có schema; app thực thi; app trả tool result; server mới tạo câu trả lời cuối cùng.

**Nếu server không hỗ trợ tool calling:** triển khai local command route trên transcript STT trước khi để phản hồi assistant hiển thị. Phải có cách hủy/bỏ qua câu trả lời LLM mâu thuẫn của command đó. Không tạo hai câu trả lời cạnh tranh.

Action allow-list ban đầu:
- OPEN_MAP(destination)
- OPEN_YOUTUBE(query optional)
- OPEN_APP(app_name)
- BACK
- HOME
- RECENTS

Cụm tiếng Việt cần hỗ trợ:
- “mở Google Maps”, “mở gg map”, “mở bản đồ”
- “tìm [địa điểm] trên bản đồ”
- “mở YouTube”
- “mở YouTube tìm [từ khóa]”
- “mở [tên ứng dụng]”
- “quay lại”
- “về màn hình chính”
- “đóng ứng dụng này” (diễn giải minh bạch là thao tác thoát/điều hướng Android được phép)

### P0.4 – Tạo state machine standby thật

Không dùng amplitude threshold thay thế wake word.

State machine chuẩn:
- STOPPED: mic off, service dừng theo yêu cầu người dùng.
- STARTING_STANDBY: xin permission/khởi tạo model.
- STANDBY: local offline wake-word engine nhận diện “TinGTinG ơi”.
- WAKE_DETECTED: phát một sự kiện, khóa debounce, chuyển quyền sở hữu audio.
- CONNECTING: kết nối Xiaozhi server và lấy hello/session.
- CONVERSATION: dùng đúng pipeline STT/TTS hiện tại.
- EXECUTING: action đang chạy; vẫn giữ trạng thái phiên.
- RETURN_TO_STANDBY: dừng conversation recorder, giải phóng audio, bật lại wake engine.
- ERROR: báo lỗi cụ thể, cho phép người dùng thử lại.

Microphone owner:
- Tại mọi thời điểm chỉ có một thành phần ghi âm.
- STANDBY: native wake engine sở hữu microphone.
- CONVERSATION: chuyển quyền microphone cho audio pipeline Xiaozhi hiện tại.
- RETURN_TO_STANDBY: dừng recorder conversation hoàn toàn trước khi bật local wake engine.

Kết thúc conversation:
- “Ngủ đi”, “Tạm biệt”, nút End: dừng session conversation, nhưng KHÔNG tắt wake engine.
- Khi không có tương tác: timeout cấu hình được, sau đó quay lại standby. Không để `VoiceCallScreen` tự giữ wake detector bằng Timer/Stream.
- Không tự restart microphone sau khi user nhấn Stop/Privacy Off.

### P0.5 – Tích hợp model wake word thực

Wake phrase chính xác: “TinGTinG ơi”.

Yêu cầu:
- Model chạy local, không gửi âm thanh standby lên server.
- Tương thích tiếng Việt hoặc model được huấn luyện/fine-tune cho phrase này.
- Có license rõ ràng, model checksum, sample rate, frame size, benchmark và hướng dẫn cài.
- Kiểm thử nhiều giọng, tốc độ, khoảng cách mic, tiếng ồn.
- Đo false acceptance và false rejection.
- Không báo “wake word ready” khi model chưa load.
- Không fake detection bằng volume threshold, keyword regex trên partial cloud STT, hoặc một timer.

Nếu không xác nhận được model phù hợp, báo rõ blocker và không giao APK với nhãn “wake word đã hoạt động”.

---

# P1 – SAU KHI P0 PASS

### P1.1 – Mở app

- Tên app tiếng Việt/Anh, normalize dấu tiếng Việt.
- PackageManager launch intent.
- Có package lookup và disambiguation.
- YouTube mở app nếu cài; nếu không cài thì báo chính xác fallback web.
- Google Maps mở app nếu cài; nếu không thì mở web map và nói rõ.

### P1.2 – Thoát app bằng Accessibility

- Cài đặt trang hướng dẫn bật Accessibility thủ công.
- BACK/HOME/RECENTS là ba action riêng.
- Nếu cần vuốt đóng thẻ trong Recents, phải test trên Android thực tế.
- Không tuyên bố force-stop.
- Không tự động đọc password, payment, private message hoặc dữ liệu nhạy cảm trên screen.

### P1.3 – Session lifetime

- Không để session bị phụ thuộc vào `VoiceCallScreen` widget lifetime.
- Activity pause khi mở Maps không được gọi `disconnect()`.
- `dispose()` không được vô tình disconnect phiên vẫn đang chạy nền.
- Chỉ user End, explicit sleep, idle timeout có kiểm soát hoặc fatal error mới kết thúc conversation session.

---

## C. LOG BẮT BUỘC

Mỗi lệnh phải có correlation ID và log các sự kiện:

```text
[VOICE] stt_transcript_received
[INTENT] open_maps destination="..."
[ACTION] method_channel_call
[ACTION] result success=true|false
[AI] assistant_reply_suppressed|tool_result_sent
[SESSION] active_after_action=true
[WAKE] model_loaded=true
[WAKE] phrase_detected=true
[AUDIO] owner=standby_wake|conversation
[EMOTION] state=listening emotion=happy source=server|text|fallback
```

Không log raw audio, access token, password, payment data hoặc transcript nhạy cảm.

---

## D. ACCEPTANCE TEST – KHÔNG ĐƯỢC BỎ QUA

### Nhóm cảm xúc
1. Chạy Debug và bật debug overlay.
2. Kiểm tra neutral → happy → sad → surprised → confused → wink.
3. Server emotion-only packet làm mặt đổi ngay, không cần đợi TTS.
4. `sentence_start` cập nhật mặt; `sentence_end` không reset quá sớm.
5. Robot nói thì miệng chuyển động; kết thúc nói thì miệng đóng.

### Nhóm action
1. “Mở Google Maps” → Maps mở; Xiaozhi nói đúng là đã mở.
2. “Mở YouTube” → app YouTube mở nếu có cài.
3. “Mở YouTube tìm nhạc jazz” → mở đúng trang/từ khóa.
4. “Mở Zalo” → mở đúng app.
5. “Quay lại” → BACK.
6. “Về màn hình chính” → HOME.
7. “Đóng ứng dụng này” → diễn giải và thực hiện một action Android được phép; không tuyên bố force-stop.
8. Action fail → nói thất bại, không nói thành công.
9. Mỗi command chạy đúng một lần; không có câu trả lời LLM mâu thuẫn.

### Nhóm wake/sleep
1. Mở app và bật trợ lý theo thao tác chủ động.
2. STANDBY hiện notification và local model ready.
3. Nói “TinGTinG ơi” → wake đúng.
4. Nói câu khác không gọi wake word → vẫn trong conversation.
5. “Mở Google Maps” → Maps mở.
6. Từ Maps nói thêm “mở YouTube” → lệnh thứ hai được nhận.
7. “Ngủ đi” → conversation kết thúc, local wake vẫn hoạt động.
8. Nói lại “TinGTinG ơi” → kết nối lại server và bắt đầu conversation.
9. Nhấn Stop/Privacy Off → mic thực sự dừng.
10. Test Android screen off, Doze, app background, OEM battery restrictions; báo rõ thiết bị/phiên bản nào không hỗ trợ.

## E. QUY TRÌNH BUILD VÀ GIAO HÀNG

- Tạo branch `fix/xiaozhi-2.0-core`.
- Baseline build trước khi sửa.
- P0 sửa và test trước; không triển khai P1 nếu P0 fail.
- Chạy:
  - `flutter pub get`
  - `dart format lib`
  - `flutter analyze`
  - `flutter test`
  - `flutter build apk --debug`
  - `flutter build apk --release`
- Build Android/Kotlin compile và test trên điện thoại thật.
- Không đổi applicationId, namespace, signing key hoặc token.
- Không push trực tiếp `main`.
- Báo rõ test nào PASS/FAIL/NOT TESTED. Không tuyên bố chức năng hoạt động nếu chưa test trên thiết bị thật.

## F. HƯỚNG DẪN CHO ANTIGRAVITY

Đầu tiên đọc nguyên văn source của:
- `lib/screens/voice_call_screen.dart`
- `lib/services/xiaozhi_service.dart`
- `lib/services/xiaozhi_websocket_manager.dart`
- `lib/services/assistant_action_executor.dart`
- `lib/utils/audio_util.dart`
- `lib/utils/emotion_detector.dart`
- `lib/widgets/robot_face.dart`
- `lib/widgets/botai_robot_avatar.dart`
- `android/app/src/main/kotlin/com/lhht/ai_assistant/MainActivity.kt`
- `android/app/src/main/kotlin/com/lhht/ai_assistant/AssistantActionExecutor.kt`
- `android/app/src/main/AndroidManifest.xml`

Sau đó tạo sơ đồ call flow hiện tại, sửa đúng các điểm gây bug đã liệt kê và test. Không thêm prompt persona để che lỗi code. Không thêm service microphone thứ hai trước khi có kế hoạch audio ownership rõ ràng.
