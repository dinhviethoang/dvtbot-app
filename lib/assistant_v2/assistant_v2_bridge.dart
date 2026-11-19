import 'dart:async';
import 'package:flutter/services.dart';
import 'assistant_mode.dart';

/// Native bridge for wake-word foreground service and user-enabled Accessibility.
/// Register this as a long-lived app service/provider, not inside a short-lived screen.
class AssistantV2Bridge {
  static const MethodChannel _methods = MethodChannel(
    'com.lhht.ai_assistant/assistant_v2',
  );
  static const EventChannel _events = EventChannel(
    'com.lhht.ai_assistant/assistant_v2_events',
  );

  Stream<AssistantNativeEvent> get events =>
      _events.receiveBroadcastStream().map(
        (value) => AssistantNativeEvent.fromMap(
          Map<Object?, Object?>.from(value as Map),
        ),
      );

  Future<bool> startWakeService() async =>
      await _methods.invokeMethod<bool>('startWakeService') ?? false;

  Future<bool> stopWakeService() async =>
      await _methods.invokeMethod<bool>('stopWakeService') ?? false;

  Future<bool> beginConversation() async =>
      await _methods.invokeMethod<bool>('beginConversation') ?? false;

  Future<bool> endConversation() async =>
      await _methods.invokeMethod<bool>('endConversation') ?? false;

  Future<bool> isAccessibilityEnabled() async =>
      await _methods.invokeMethod<bool>('isAccessibilityEnabled') ?? false;

  Future<void> openAccessibilitySettings() =>
      _methods.invokeMethod<void>('openAccessibilitySettings');

  Future<bool> back() async =>
      await _methods.invokeMethod<bool>('accessibilityBack') ?? false;

  Future<bool> home() async =>
      await _methods.invokeMethod<bool>('accessibilityHome') ?? false;

  Future<bool> recents() async =>
      await _methods.invokeMethod<bool>('accessibilityRecents') ?? false;

  Future<bool> scrollForward() async =>
      await _methods.invokeMethod<bool>('accessibilityScrollForward') ?? false;

  Future<bool> clickVisibleText(String label) async =>
      await _methods.invokeMethod<bool>(
        'accessibilityClickText',
        <String, Object>{'label': label},
      ) ??
      false;
}

class AssistantNativeEvent {
  const AssistantNativeEvent({required this.mode, this.reason});

  final AssistantMode mode;
  final String? reason;

  factory AssistantNativeEvent.fromMap(Map<Object?, Object?> map) {
    return AssistantNativeEvent(
      mode: assistantModeFromNative(map['state'] as String?),
      reason: map['reason'] as String?,
    );
  }
}
