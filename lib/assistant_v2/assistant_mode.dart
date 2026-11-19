/// Shared UI/session states for Xiaozhi 2.0.
///
/// Native broadcasts use the same wire values in AssistantV2Contract.kt.
enum AssistantMode {
  stopped,
  standby,
  wakeDetected,
  conversation,
  executing,
  listening,
  thinking,
  speaking,
  error,
}

AssistantMode assistantModeFromNative(String? value) {
  switch (value) {
    case 'stopped':
      return AssistantMode.stopped;
    case 'standby':
      return AssistantMode.standby;
    case 'wake_detected':
      return AssistantMode.wakeDetected;
    case 'conversation':
      return AssistantMode.conversation;
    case 'executing':
      return AssistantMode.executing;
    case 'listening':
      return AssistantMode.listening;
    case 'thinking':
      return AssistantMode.thinking;
    case 'speaking':
      return AssistantMode.speaking;
    case 'error':
    default:
      return AssistantMode.error;
  }
}

/// User-facing policy:
/// - standby: local wake detector only
/// - conversation: existing Xiaozhi STT/TTS/WebSocket pipeline
/// - executing: tools may run, but the conversation session remains alive
/// - end session: return to standby, never silently leave the microphone active
const String xiaozhiWakePhrase = 'TinGTinG ơi';
