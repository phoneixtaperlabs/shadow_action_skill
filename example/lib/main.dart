import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shadow_action_skill/shadow_action_skill.dart';

import 'sections/accessibility_section.dart';
import 'sections/dictation_section.dart';
import 'sections/quick_access_section.dart';
import 'sections/screenshot_section.dart';
import 'sections/skill_result_section.dart';
import 'sections/skill_search_section.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _shadowActionSkillPlugin = ShadowActionSkill();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion = await _shadowActionSkillPlugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text('Running on: $_platformVersion', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            // Temporary: Audio Device Select test (remove after testing)
            ElevatedButton(
              onPressed: () async {
                try {
                  await const MethodChannel('shadow_action_skill').invokeMethod('showGlowOverlay');
                  debugPrint('[Test] showAudioDeviceSelect — window should appear');
                } catch (e) {
                  debugPrint('[Test] showAudioDeviceSelect failed: \$e');
                }
              },
              child: const Text('Select Audio Device'),
            ),
            const SizedBox(height: 24),
            const QuickAccessSection(),
            const SizedBox(height: 32),
            const SkillSearchSection(),
            const SizedBox(height: 32),
            const SkillResultSection(),
            const SizedBox(height: 32),
            const AccessibilitySection(),
            const SizedBox(height: 32),
            const DictationSection(),
            const SizedBox(height: 32),
            const ScreenshotSection(),
          ],
        ),
      ),
    );
  }
}
