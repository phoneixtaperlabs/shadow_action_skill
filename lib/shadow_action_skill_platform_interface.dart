import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'shadow_action_skill_method_channel.dart';

abstract class ShadowActionSkillPlatform extends PlatformInterface {
  /// Constructs a ShadowActionSkillPlatform.
  ShadowActionSkillPlatform() : super(token: _token);

  static final Object _token = Object();

  static ShadowActionSkillPlatform _instance = MethodChannelShadowActionSkill();

  /// The default instance of [ShadowActionSkillPlatform] to use.
  ///
  /// Defaults to [MethodChannelShadowActionSkill].
  static ShadowActionSkillPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ShadowActionSkillPlatform] when
  /// they register themselves.
  static set instance(ShadowActionSkillPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<void> startDictation(Map<String, dynamic> config) {
    throw UnimplementedError('startDictation() has not been implemented.');
  }

  Future<void> stopDictation() {
    throw UnimplementedError('stopDictation() has not been implemented.');
  }

  Future<void> dismissDictationView() {
    throw UnimplementedError('dismissDictationView() has not been implemented.');
  }

  void setNativeCallHandler(Future<dynamic> Function(MethodCall call)? handler) {
    throw UnimplementedError('setNativeCallHandler() has not been implemented.');
  }

  Future<bool> checkAccessibilityPermission() {
    throw UnimplementedError('checkAccessibilityPermission() has not been implemented.');
  }

  Future<bool> requestAccessibilityPermission() {
    throw UnimplementedError('requestAccessibilityPermission() has not been implemented.');
  }

  Future<String?> getClipboardContent() {
    throw UnimplementedError('getClipboardContent() has not been implemented.');
  }

  Future<void> setClipboardContent(String text) {
    throw UnimplementedError('setClipboardContent() has not been implemented.');
  }

  Future<String> copy({bool selectAll = false}) {
    throw UnimplementedError('copy() has not been implemented.');
  }

  Future<void> paste(String text) {
    throw UnimplementedError('paste() has not been implemented.');
  }

  Future<Map<String, dynamic>> captureScreenshot({double quality = 0.8, String? fileName}) {
    throw UnimplementedError('captureScreenshot() has not been implemented.');
  }

  Future<void> showGlowOverlay() {
    throw UnimplementedError('showGlowOverlay() has not been implemented.');
  }

  Future<void> dismissGlowOverlay() {
    throw UnimplementedError('dismissGlowOverlay() has not been implemented.');
  }

  Future<void> showQuickAccess(List<Map<String, dynamic>> skills) {
    throw UnimplementedError('showQuickAccess() has not been implemented.');
  }

  Future<void> dismissQuickAccess() {
    throw UnimplementedError('dismissQuickAccess() has not been implemented.');
  }

  Future<void> showSkillSearch(List<Map<String, dynamic>> skills) {
    throw UnimplementedError('showSkillSearch() has not been implemented.');
  }

  Future<void> dismissSkillSearch() {
    throw UnimplementedError('dismissSkillSearch() has not been implemented.');
  }

  Future<void> showSkillResult({
    required String skillName,
    required String skillIcon,
    Uint8List? skillIconBytes,
    required String resultText,
    List<Map<String, dynamic>> contexts = const [],
  }) {
    throw UnimplementedError('showSkillResult() has not been implemented.');
  }

  Future<void> dismissSkillResult() {
    throw UnimplementedError('dismissSkillResult() has not been implemented.');
  }

  Future<void> showCopyConfirmation() {
    throw UnimplementedError('showCopyConfirmation() has not been implemented.');
  }

  Future<void> dismissCopyConfirmation() {
    throw UnimplementedError('dismissCopyConfirmation() has not been implemented.');
  }

  Future<void> muteSystemOutput() {
    throw UnimplementedError('muteSystemOutput() has not been implemented.');
  }

  Future<void> restoreSystemVolume() {
    throw UnimplementedError('restoreSystemVolume() has not been implemented.');
  }

  Future<String?> getDefaultInputDeviceName() {
    throw UnimplementedError('getDefaultInputDeviceName() has not been implemented.');
  }

  Future<void> showDeviceNotification(String deviceName) {
    throw UnimplementedError('showDeviceNotification() has not been implemented.');
  }

  Future<void> dismissDeviceNotification() {
    throw UnimplementedError('dismissDeviceNotification() has not been implemented.');
  }

  Future<void> showDictationFail() {
    throw UnimplementedError('showDictationFail() has not been implemented.');
  }

  Future<void> dismissDictationFail() {
    throw UnimplementedError('dismissDictationFail() has not been implemented.');
  }

  Future<void> showAudioDeviceSelect() {
    throw UnimplementedError('showAudioDeviceSelect() has not been implemented.');
  }

  Future<void> dismissAudioDeviceSelect() {
    throw UnimplementedError('dismissAudioDeviceSelect() has not been implemented.');
  }
}
