import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_action_skill/shadow_action_skill_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelShadowActionSkill platform = MethodChannelShadowActionSkill();
  const MethodChannel channel = MethodChannel('shadow_action_skill');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getPlatformVersion':
            return '42';
          case 'startDictation':
            return null;
          case 'stopDictation':
            return null;
          case 'dismissDictationView':
            return null;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('startDictation', () async {
    await platform.startDictation({'asrEngine': 'whisper'});
  });

  test('stopDictation', () async {
    await platform.stopDictation();
  });

  test('dismissDictationView', () async {
    await platform.dismissDictationView();
  });

  test('setNativeCallHandler', () async {
    final List<String> receivedMethods = [];

    platform.setNativeCallHandler((MethodCall call) async {
      receivedMethods.add(call.method);
      return null;
    });

    // Simulate a native → Dart call
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'shadow_action_skill',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onTestEvent', {'key': 'value'}),
      ),
      (ByteData? data) {},
    );

    expect(receivedMethods, ['onTestEvent']);
  });
}
