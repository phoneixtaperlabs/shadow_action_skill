import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'shadow_action_skill_platform_interface.dart';

/// An implementation of [ShadowActionSkillPlatform] that uses method channels.
class MethodChannelShadowActionSkill extends ShadowActionSkillPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('shadow_action_skill');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> startDictation(Map<String, dynamic> config) async {
    await methodChannel.invokeMethod<void>('startDictation', config);
  }

  @override
  Future<void> stopDictation() async {
    await methodChannel.invokeMethod<void>('stopDictation');
  }

  @override
  Future<void> dismissDictationView() async {
    await methodChannel.invokeMethod<void>('dismissDictationView');
  }

  @override
  void setNativeCallHandler(Future<dynamic> Function(MethodCall call)? handler) {
    methodChannel.setMethodCallHandler(handler);
  }

  @override
  Future<bool> checkAccessibilityPermission() async {
    final result = await methodChannel.invokeMethod<bool>('checkAccessibilityPermission');
    return result ?? false;
  }

  @override
  Future<bool> requestAccessibilityPermission() async {
    final result = await methodChannel.invokeMethod<bool>('requestAccessibilityPermission');
    return result ?? false;
  }

  @override
  Future<String?> getClipboardContent() async {
    return await methodChannel.invokeMethod<String>('getClipboardContent');
  }

  @override
  Future<void> setClipboardContent(String text) async {
    await methodChannel.invokeMethod<void>('setClipboardContent', {'text': text});
  }

  @override
  Future<String> copy({bool selectAll = false}) async {
    final result = await methodChannel.invokeMethod<String>('copy', {'selectAll': selectAll});
    return result ?? '';
  }

  @override
  Future<void> paste(String text) async {
    await methodChannel.invokeMethod<void>('paste', {'text': text});
  }

  @override
  Future<Map<String, dynamic>> captureScreenshot({double quality = 0.8, String? fileName}) async {
    final result = await methodChannel.invokeMapMethod<String, dynamic>(
      'captureScreenshot',
      {'quality': quality, if (fileName != null) 'fileName': fileName},
    );
    return result!;
  }

  @override
  Future<void> showGlowOverlay() async {
    await methodChannel.invokeMethod<void>('showGlowOverlay');
  }

  @override
  Future<void> dismissGlowOverlay() async {
    await methodChannel.invokeMethod<void>('dismissGlowOverlay');
  }

  @override
  Future<void> showQuickAccess(List<Map<String, dynamic>> skills) async {
    await methodChannel.invokeMethod<void>('showQuickAccess', {'skills': skills});
  }

  @override
  Future<void> dismissQuickAccess() async {
    await methodChannel.invokeMethod<void>('dismissQuickAccess');
  }

  @override
  Future<void> showSkillSearch(List<Map<String, dynamic>> skills) async {
    await methodChannel.invokeMethod<void>('showSkillSearch', {'skills': skills});
  }

  @override
  Future<void> dismissSkillSearch() async {
    await methodChannel.invokeMethod<void>('dismissSkillSearch');
  }

  @override
  Future<void> showSkillResult({
    required String skillName,
    required String skillIcon,
    Uint8List? skillIconBytes,
    required String resultText,
    List<Map<String, dynamic>> contexts = const [],
  }) async {
    await methodChannel.invokeMethod<void>('showSkillResult', {
      'skillName': skillName,
      'skillIcon': skillIcon,
      if (skillIconBytes != null) 'skillIconBytes': skillIconBytes,
      'resultText': resultText,
      'contexts': contexts,
    });
  }

  @override
  Future<void> dismissSkillResult() async {
    await methodChannel.invokeMethod<void>('dismissSkillResult');
  }

  @override
  Future<void> showCopyConfirmation() async {
    await methodChannel.invokeMethod<void>('showCopyConfirmation');
  }

  @override
  Future<void> dismissCopyConfirmation() async {
    await methodChannel.invokeMethod<void>('dismissCopyConfirmation');
  }

  @override
  Future<void> muteSystemOutput() async {
    await methodChannel.invokeMethod<void>('muteSystemOutput');
  }

  @override
  Future<void> restoreSystemVolume() async {
    await methodChannel.invokeMethod<void>('restoreSystemVolume');
  }

  @override
  Future<String?> getDefaultInputDeviceName() async {
    return await methodChannel.invokeMethod<String>('getDefaultInputDeviceName');
  }

  @override
  Future<void> showDeviceNotification(String deviceName) async {
    await methodChannel.invokeMethod<void>('showDeviceNotification', {'deviceName': deviceName});
  }

  @override
  Future<void> dismissDeviceNotification() async {
    await methodChannel.invokeMethod<void>('dismissDeviceNotification');
  }

  @override
  Future<void> showDictationFail() async {
    await methodChannel.invokeMethod<void>('showDictationFail');
  }

  @override
  Future<void> dismissDictationFail() async {
    await methodChannel.invokeMethod<void>('dismissDictationFail');
  }

  @override
  Future<void> showAudioDeviceSelect() async {
    await methodChannel.invokeMethod<void>('showAudioDeviceSelect');
  }

  @override
  Future<void> dismissAudioDeviceSelect() async {
    await methodChannel.invokeMethod<void>('dismissAudioDeviceSelect');
  }

  @override
  Future<void> showActionSkillUnavailable() async {
    await methodChannel.invokeMethod<void>('showActionSkillUnavailable');
  }

  @override
  Future<void> dismissActionSkillUnavailable() async {
    await methodChannel.invokeMethod<void>('dismissActionSkillUnavailable');
  }
}
