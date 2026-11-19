# ANTIGRAVITY TASK – IMPLEMENT XIAOZHI 2.0 IN THE EXISTING REPOSITORY

Repository: https://github.com/dinhviethoang/dvtbot-app
Default branch verified during preparation: `main`
Android namespace: `com.lhht.ai_assistant`
Application ID: `com.king.hdvbot`

Read `README_VI.md` and `INTEGRATION_NOTES.md` first.

## Non-negotiable requirements

This is an upgrade to the existing app. Do not create a new Flutter project.
Do not replace the OTA, WebSocket, STT, TTS, Opus, session, settings, or emotion systems.
Do not change applicationId, namespace, signing config, server protocol, tokens, or API endpoints.
Do not overwrite existing files without reading their full contents and understanding call sites.

Wake phrase is exactly: **“TinGTinG ơi”**.

Desired flow:
1. STANDBY: local offline wake-word detection only.
2. On wake: enter CONVERSATION.
3. Keep the existing Xiaozhi conversation/session alive across app launches and external apps.
4. Execute multiple commands without requiring the wake phrase again.
5. Opening Google Maps must not stop listening or disconnect the active session.
6. On “Tạm biệt”, “Ngủ đi”, explicit end button, or configurable idle timeout, return to STANDBY.

## Important architecture constraint

There must be exactly one microphone owner at a time.
Do not let `VoiceCallScreen`, `AudioUtil`, `WakeWordForegroundService`, and another service
start independent AudioRecord/record plugin instances concurrently.

In standby, native foreground microphone service may own audio and feed PCM frames to a real
offline wake-word model. In conversation, transfer audio ownership safely to the existing
Xiaozhi STT/WebSocket pipeline, then restore the wake-word owner after the conversation ends.

Do not use loudness/amplitude threshold as a substitute for wake phrase recognition.
The provided `WakeWordEngine.create()` intentionally fails closed until a real model is integrated.
Choose and document an offline keyword-spotting model/runtime that supports the exact Vietnamese
phrase; include its model assets, licensing, checksum, sample rate and false-positive testing.
Do not claim wake word is working until actual on-device recognition is demonstrated.

## Work stages

### Stage 0 – Audit
- Inspect full source of `VoiceCallScreen`, `XiaozhiService`, `XiaozhiWebSocketManager`,
  `AudioUtil`, `MainActivity`, `AssistantActionExecutor`, `FloatingAvatarService`, `RobotFace`.
- Produce a short architecture map and identify lifecycle disconnects.
- Run baseline `flutter analyze` and build debug before editing.
- Report existing uncommitted changes; do not discard them.

### Stage 1 – UI
- Redesign voice screen: absolute black background, only expressive neon-blue robot eyes and mouth.
- Reuse `RobotFace` and existing emotion mapping/animation.
- Add standby, wakeDetected, listening, thinking, speaking, executing and error states.
- Remove visible avatar shell/body and chat transcript from the main conversation screen.
- Preserve minimal privacy/settings/end controls.
- Build and test before moving on.

### Stage 2 – Native background audio and wake word
- Merge provided Kotlin starter files into existing package.
- Merge manifest additions; do not replace current manifest.
- Add runtime notification/microphone permission UX.
- Integrate a real offline wake-word engine for “TinGTinG ơi”.
- Implement Native -> Flutter event bridge.
- Ensure service is started only from a valid visible user action and notification remains visible.
- Handle Android 14+ microphone foreground service requirements and OEM battery restrictions.
- Never silently restart microphone after user stops it.
- Build and test on a physical Android phone.

### Stage 3 – Session continuity
- Refactor session ownership so `XiaozhiService` and WebSocket session are not owned by
  `VoiceCallScreen` widget lifetime.
- Activity pause/background must not disconnect the session.
- On external app launch, keep conversation audio active and return audio focus correctly.
- After each tool execution, resume listening without a new wake phrase.
- Add interruption/barge-in handling and reconnect logic without duplicating sessions.

### Stage 4 – Phone control
- Keep existing `AssistantActionExecutor` and `openGoogleMaps` implementation.
- Add app launch via PackageManager/launch intents.
- Add explicit actions for BACK, HOME, RECENTS.
- Add Accessibility Service using the supplied XML/service class.
- Require the user to enable Accessibility manually in Android Settings.
- Use allow-listed actions only. Never silently tap payment, purchase, send, delete, post,
  password, or account-security controls. Require explicit confirmation for consequential actions.
- Do not claim arbitrary force-stop of other apps; Android generally restricts it.

### Stage 5 – AI command orchestration
- Add typed action schema and command dispatcher.
- Separate CHAT from OPEN_APP, NAVIGATION, SYSTEM_ACTION, ACCESSIBILITY_ACTION, REMINDER.
- Preserve context across multiple utterances.
- Do not invent success: confirm an action only after Android reports it succeeded.
- After opening Maps, continue accepting follow-up commands such as “tìm quán cà phê gần đó”.

### Stage 6 – Acceptance tests
Must pass:
- Start assistant from visible app.
- Wake with “TinGTinG ơi”.
- Hold a multi-turn conversation without repeating wake phrase.
- “Mở Google Maps” -> Maps opens.
- While Maps is foreground, say another command -> it is received and executed.
- Accessibility actions only work after user grants permission.
- “Tạm biệt” -> conversation ends and local wake standby resumes.
- Notification stop action -> microphone stops and service ends.
- Denied permission -> graceful explanation; no false “listening” state.
- No duplicate recorder, WebSocket, or session.
- Reconnect after network interruption without duplicate audio streams.

At each stage run:
- `flutter pub get`
- `dart format lib`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`

Also run Android Gradle/Kotlin compilation. Fix errors before moving to the next stage.

## Deliverables
- Integrated source changes in a dedicated branch `feature/xiaozhi-2.0`.
- A concise list of changed files and architectural decisions.
- Build logs and test results.
- Debug APK.
- List of remaining limitations, especially wake-word model licensing/accuracy and Android background restrictions.
- Do not push directly to `main`; create a branch and report the branch/commit.
