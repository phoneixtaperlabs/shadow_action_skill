import 'package:flutter/services.dart';

import 'dictation_config.dart';
import 'quick_access_skill.dart';
import 'shadow_action_skill_platform_interface.dart';
import 'skill_result.dart';
import 'skill_search_skill.dart';

export 'dictation_config.dart';
export 'quick_access_skill.dart';
export 'skill_result.dart';
export 'skill_search_skill.dart';

/// Flutter plugin for macOS overlay UI (dictation, quick access, skill search, skill result).
///
/// Native→Flutter callbacks are received via [setNativeCallHandler].
class ShadowActionSkill {
  /// Returns the macOS version string, or `null` if unavailable.
  Future<String?> getPlatformVersion() {
    return ShadowActionSkillPlatform.instance.getPlatformVersion();
  }

  /// Starts a dictation session with the given [config].
  Future<void> startDictation(DictationConfig config) {
    return ShadowActionSkillPlatform.instance.startDictation(config.toMap());
  }

  /// Stops the active dictation session.
  Future<void> stopDictation() {
    return ShadowActionSkillPlatform.instance.stopDictation();
  }

  /// Dismisses the dictation overlay window.
  Future<void> dismissDictationView() {
    return ShadowActionSkillPlatform.instance.dismissDictationView();
  }

  /// Registers a handler for native→Flutter callbacks.
  ///
  /// Callback methods and their argument shapes:
  ///
  /// **Dictation:**
  /// - `onTranscription` — `{text: String, isFinal: bool, confidence: double, segments: List<{text, startTime, endTime, confidence}>}`
  /// - `onNoSpeechDetected` — no args
  /// - `onDictationCancelled` — no args
  /// - `onDictationConfirmed` — no args
  /// - `onSelectMicrophoneTapped` — no args
  /// - `onDictationFailDismissed` — no args
  ///
  /// **Quick Access:**
  /// - `onQuickAccessSkillSelected` — `{skillId: String, key: String}`
  ///
  /// **Skill Search:**
  /// - `onSkillSearchSelected` — `{skillId: String, shortcut: String}`
  ///
  /// **Skill Result:**
  /// - `onSkillResultAction` — `{actionId: String, text: String}`
  /// - `onSkillResultDismissed` — no args
  /// - `onCopyConfirmationDismissed` — no args
  ///
  /// **Other:**
  /// - `onAudioDeviceSelectDismissed` — no args
  /// - `onActionSkillUnavailableDismissed` — no args
  /// - `onError` — `{code: String, message: String, details: dynamic}`
  /// - `onWindowEvent` — varies by event
  void setNativeCallHandler(Future<dynamic> Function(MethodCall call)? handler) {
    ShadowActionSkillPlatform.instance.setNativeCallHandler(handler);
  }

  /// Returns `true` if accessibility permission is granted.
  Future<bool> checkAccessibilityPermission() {
    return ShadowActionSkillPlatform.instance.checkAccessibilityPermission();
  }

  /// Opens the system accessibility permission prompt. Returns `true` if granted.
  Future<bool> requestAccessibilityPermission() {
    return ShadowActionSkillPlatform.instance.requestAccessibilityPermission();
  }

  /// Returns the current clipboard text, or `null` if empty.
  Future<String?> getClipboardContent() {
    return ShadowActionSkillPlatform.instance.getClipboardContent();
  }

  /// Sets the system clipboard to [text].
  Future<void> setClipboardContent(String text) {
    return ShadowActionSkillPlatform.instance.setClipboardContent(text);
  }

  /// Simulates ⌘C (or ⌘A+⌘C if [selectAll] is `true`). Returns the copied text.
  Future<String> copy({bool selectAll = false}) {
    return ShadowActionSkillPlatform.instance.copy(selectAll: selectAll);
  }

  /// Sets clipboard to [text] then simulates ⌘V to paste.
  Future<void> paste(String text) {
    return ShadowActionSkillPlatform.instance.paste(text);
  }

  /// Captures a screenshot of the current screen.
  ///
  /// Returns `{filePath: String, timestamp: int}`.
  Future<Map<String, dynamic>> captureScreenshot({double quality = 0.8, String? fileName}) {
    return ShadowActionSkillPlatform.instance.captureScreenshot(quality: quality, fileName: fileName);
  }

  /// Shows the glow overlay effect.
  Future<void> showGlowOverlay() {
    return ShadowActionSkillPlatform.instance.showGlowOverlay();
  }

  /// Dismisses the glow overlay effect.
  Future<void> dismissGlowOverlay() {
    return ShadowActionSkillPlatform.instance.dismissGlowOverlay();
  }

  /// Shows the quick access popup with the given [skills].
  Future<void> showQuickAccess(List<QuickAccessSkill> skills) {
    return ShadowActionSkillPlatform.instance
        .showQuickAccess(skills.map((s) => s.toMap()).toList());
  }

  /// Dismisses the quick access popup.
  Future<void> dismissQuickAccess() {
    return ShadowActionSkillPlatform.instance.dismissQuickAccess();
  }

  /// Shows the skill search overlay with the given [skills].
  Future<void> showSkillSearch(List<SkillSearchSkill> skills) {
    return ShadowActionSkillPlatform.instance
        .showSkillSearch(skills.map((s) => s.toMap()).toList());
  }

  /// Dismisses the skill search overlay.
  Future<void> dismissSkillSearch() {
    return ShadowActionSkillPlatform.instance.dismissSkillSearch();
  }

  /// Shows the skill result overlay.
  Future<void> showSkillResult(SkillResult result) {
    final map = result.toMap();
    return ShadowActionSkillPlatform.instance.showSkillResult(
      skillName: map['skillName'] as String,
      skillIcon: map['skillIcon'] as String,
      skillIconBytes: map['skillIconBytes'] as Uint8List?,
      resultText: map['resultText'] as String,
      contexts: map['contexts'] as List<Map<String, dynamic>>,
    );
  }

  /// Dismisses the skill result overlay.
  Future<void> dismissSkillResult() {
    return ShadowActionSkillPlatform.instance.dismissSkillResult();
  }

  /// Shows the copy confirmation banner ("Copied. Paste anywhere.").
  Future<void> showCopyConfirmation() {
    return ShadowActionSkillPlatform.instance.showCopyConfirmation();
  }

  /// Dismisses the copy confirmation banner.
  Future<void> dismissCopyConfirmation() {
    return ShadowActionSkillPlatform.instance.dismissCopyConfirmation();
  }

  /// Mutes the system output device using the hardware mute flag.
  Future<void> muteSystemOutput() {
    return ShadowActionSkillPlatform.instance.muteSystemOutput();
  }

  /// Unmutes the system output device.
  /// No-op if not currently muted.
  Future<void> restoreSystemVolume() {
    return ShadowActionSkillPlatform.instance.restoreSystemVolume();
  }

  /// Returns the default input device name, or `null` if no device exists.
  Future<String?> getDefaultInputDeviceName() {
    return ShadowActionSkillPlatform.instance.getDefaultInputDeviceName();
  }

  /// Shows a device notification with the given [deviceName].
  Future<void> showDeviceNotification(String deviceName) {
    return ShadowActionSkillPlatform.instance.showDeviceNotification(deviceName);
  }

  /// Dismisses the device notification.
  Future<void> dismissDeviceNotification() {
    return ShadowActionSkillPlatform.instance.dismissDeviceNotification();
  }

  /// Shows the dictation fail view.
  Future<void> showDictationFail() {
    return ShadowActionSkillPlatform.instance.showDictationFail();
  }

  /// Dismisses the dictation fail view.
  Future<void> dismissDictationFail() {
    return ShadowActionSkillPlatform.instance.dismissDictationFail();
  }

  /// Shows the audio device selection view.
  Future<void> showAudioDeviceSelect() {
    return ShadowActionSkillPlatform.instance.showAudioDeviceSelect();
  }

  /// Dismisses the audio device selection view.
  Future<void> dismissAudioDeviceSelect() {
    return ShadowActionSkillPlatform.instance.dismissAudioDeviceSelect();
  }
}
