import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadow_action_skill/shadow_action_skill.dart';

class DictationSection extends StatefulWidget {
  const DictationSection({
    super.key,
    required this.plugin,
    required this.addHandler,
    required this.removeHandler,
  });

  final ShadowActionSkill plugin;
  final void Function(Future<dynamic> Function(MethodCall)) addHandler;
  final void Function(Future<dynamic> Function(MethodCall)) removeHandler;

  @override
  State<DictationSection> createState() => _DictationSectionState();
}

class _DictationSectionState extends State<DictationSection> {
  String _dictationStatus = '';
  String _transcriptionText = '';

  @override
  void initState() {
    super.initState();
    widget.addHandler(_handleNativeCall);
  }

  @override
  void dispose() {
    widget.removeHandler(_handleNativeCall);
    super.dispose();
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    developer.log('[Dart] Native call received: ${call.method}', name: 'Dictation');
    switch (call.method) {
      case 'onTranscription':
        final args = call.arguments as Map<dynamic, dynamic>;
        final text = args['text'] as String? ?? '';
        final isFinal = args['isFinal'] as bool? ?? false;
        debugPrint('[Dictation] onTranscription: isFinal=$isFinal, text="$text"');
        if (!mounted) return;
        setState(() {
          _transcriptionText = text;
          _dictationStatus = isFinal ? 'Final' : 'Partial...';
        });
      case 'onDictationCancelled':
        debugPrint('[Dictation] User cancelled dictation');
        if (!mounted) return;
        setState(() {
          _dictationStatus = 'Dictation cancelled by user.';
        });
      case 'onDictationConfirmed':
        debugPrint('[Dictation] User confirmed dictation');
        if (!mounted) return;
        setState(() {
          _dictationStatus = 'Dictation confirmed by user.';
        });
      case 'onNoSpeechDetected':
        debugPrint('[Dictation] No speech detected — stopping dictation, showing fail view');
        if (!mounted) return;
        setState(() {
          _dictationStatus = 'No speech detected.';
        });
        await widget.plugin.dismissDictationView();
        await widget.plugin.showDictationFail();
        await widget.plugin.stopDictation();
        await widget.plugin.restoreSystemVolume();
      case 'onSelectMicrophoneTapped':
        debugPrint('[Dictation] User tapped Select microphone');
        await widget.plugin.dismissDictationFail();
        await widget.plugin.showAudioDeviceSelect();
      case 'onDictationFailDismissed':
        debugPrint('[Dictation] User dismissed fail view');
        await widget.plugin.dismissDictationFail();

      case 'onAudioDeviceSelectDismissed':
        debugPrint('[Dication] User dismissed Audio Device Select view');
        await widget.plugin.dismissAudioDeviceSelect();
    }
  }

  Future<void> _startDictation() async {
    try {
      setState(() {
        _transcriptionText = '';
      });

      // Mute system output to prevent speaker feedback during dictation.
      await widget.plugin.muteSystemOutput();

      // Get the default input device name and show a notification.
      final deviceName = await widget.plugin.getDefaultInputDeviceName();
      if (deviceName != null) {
        await widget.plugin.showDeviceNotification(deviceName);
      }

      await widget.plugin.startDictation(const DictationConfig(whisperModel: WhisperModel.smallQ5_1));
      if (!mounted) return;
      setState(() {
        _dictationStatus = 'Dictation started.';
      });
    } on PlatformException catch (e) {
      // Restore volume if start fails partway through.
      try {
        await widget.plugin.restoreSystemVolume();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _dictationStatus = 'Failed to start dictation: ${e.message}';
      });
    }
  }

  Future<void> _stopDictation() async {
    try {
      await widget.plugin.stopDictation();
      // Restore volume after dictation stops (safety net also restores on native side).
      await widget.plugin.restoreSystemVolume();
      if (!mounted) return;
      setState(() {
        _dictationStatus = 'Dictation stopped.';
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _dictationStatus = 'Failed to stop dictation: ${e.message}';
      });
    }
  }

  Future<void> _dismissDictationView() async {
    try {
      await widget.plugin.dismissDictationView();
      if (!mounted) return;
      setState(() {
        _dictationStatus = 'Dictation view dismissed.';
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _dictationStatus = 'Failed to dismiss dictation view: ${e.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dictation', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton(onPressed: _startDictation, child: const Text('Start Dictation')),
            ElevatedButton(onPressed: _stopDictation, child: const Text('Stop Dictation')),
            ElevatedButton(onPressed: _dismissDictationView, child: const Text('Dismiss Dictation View')),
            ElevatedButton(
              onPressed: () async {
                await widget.plugin.showDictationFail();
              },
              child: const Text('Show Dictation Fail'),
            ),
            ElevatedButton(
              onPressed: () async {
                await widget.plugin.dismissDictationFail();
              },
              child: const Text('Dismiss Dictation Fail'),
            ),
            ElevatedButton(
              onPressed: () async {
                await widget.plugin.showAudioDeviceSelect();
              },
              child: const Text('Show Audio Device Select'),
            ),
            ElevatedButton(
              onPressed: () async {
                await widget.plugin.dismissAudioDeviceSelect();
              },
              child: const Text('Dismiss Audio Device Select'),
            ),
            ElevatedButton(
              onPressed: () async {
                final deviceName = await widget.plugin.getDefaultInputDeviceName();
                if (deviceName != null) {
                  await widget.plugin.showDeviceNotification(deviceName);
                }
              },
              child: const Text('Show Device Notification'),
            ),
            ElevatedButton(
              onPressed: () async {
                await widget.plugin.dismissDeviceNotification();
              },
              child: const Text('Dismiss Device Notification'),
            ),
            ElevatedButton(
              onPressed: () async {
                await widget.plugin.showActionSkillUnavailable();
              },
              child: const Text('Show Action Skill Unavailable'),
            ),
            ElevatedButton(
              onPressed: () async {
                await widget.plugin.dismissActionSkillUnavailable();
              },
              child: const Text('Dismiss Action Skill Unavailable'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_dictationStatus.isNotEmpty)
          Text(
            _dictationStatus,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _dictationStatus.startsWith('Failed') ? Colors.red : Colors.green),
          ),
        const SizedBox(height: 8),
        if (_transcriptionText.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: Text(_transcriptionText, style: Theme.of(context).textTheme.bodyLarge),
          ),
      ],
    );
  }
}
