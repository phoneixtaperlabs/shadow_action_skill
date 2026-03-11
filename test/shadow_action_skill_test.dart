import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_action_skill/shadow_action_skill.dart';
import 'package:shadow_action_skill/shadow_action_skill_platform_interface.dart';
import 'package:shadow_action_skill/shadow_action_skill_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockShadowActionSkillPlatform
    with MockPlatformInterfaceMixin
    implements ShadowActionSkillPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<void> startDictation(Map<String, dynamic> config) => Future.value();

  @override
  Future<void> stopDictation() => Future.value();

  @override
  Future<void> dismissDictationView() => Future.value();

  @override
  void setNativeCallHandler(Future<dynamic> Function(MethodCall call)? handler) {}
}

void main() {
  final ShadowActionSkillPlatform initialPlatform = ShadowActionSkillPlatform.instance;

  test('$MethodChannelShadowActionSkill is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelShadowActionSkill>());
  });

  test('getPlatformVersion', () async {
    ShadowActionSkill shadowActionSkillPlugin = ShadowActionSkill();
    MockShadowActionSkillPlatform fakePlatform = MockShadowActionSkillPlatform();
    ShadowActionSkillPlatform.instance = fakePlatform;

    expect(await shadowActionSkillPlugin.getPlatformVersion(), '42');
  });
}
