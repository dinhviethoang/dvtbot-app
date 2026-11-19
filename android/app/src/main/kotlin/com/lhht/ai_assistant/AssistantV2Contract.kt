package com.lhht.ai_assistant

/**
 * Shared contract for Xiaozhi 2.0.
 * Keep this state vocabulary aligned with Flutter's AssistantMode.
 */
object AssistantV2Contract {
    const val ACTION_STATE_CHANGED = "com.lhht.ai_assistant.ASSISTANT_V2_STATE"
    const val EXTRA_STATE = "state"
    const val EXTRA_REASON = "reason"

    const val STATE_STOPPED = "stopped"
    const val STATE_STANDBY = "standby"
    const val STATE_WAKE_DETECTED = "wake_detected"
    const val STATE_CONVERSATION = "conversation"
    const val STATE_EXECUTING = "executing"
    const val STATE_ERROR = "error"

    const val CHANNEL = "com.lhht.ai_assistant/assistant_v2"
    const val EVENT_CHANNEL = "com.lhht.ai_assistant/assistant_v2_events"

    const val NOTIFICATION_CHANNEL_ID = "xiaozhi_assistant"
    const val NOTIFICATION_ID = 2302

    const val WAKE_PHRASE_DISPLAY = "TinGTinG ơi"
}
