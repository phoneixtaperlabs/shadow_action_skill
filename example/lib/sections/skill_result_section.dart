import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadow_action_skill/shadow_action_skill.dart';

class SkillResultSection extends StatefulWidget {
  const SkillResultSection({super.key});

  @override
  State<SkillResultSection> createState() => _SkillResultSectionState();
}

class _SkillResultSectionState extends State<SkillResultSection> {
  final _plugin = ShadowActionSkill();

  String _status = '';
  bool _isStatusError = false;

  @override
  void initState() {
    super.initState();
    _plugin.setNativeCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (!mounted) return;
    switch (call.method) {
      case 'onSkillResultAction':
        final args = call.arguments as Map<dynamic, dynamic>;
        final actionId = args['actionId'] as String?;
        final text = args['text'] as String?;
        _setStatus('Action: $actionId, text length: ${text?.length ?? 0}');
      case 'onSkillResultDismissed':
        _setStatus('SkillResult dismissed by user');
    }
  }

  void _setStatus(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _status = message;
      _isStatusError = isError;
    });
  }

  Future<Uint8List> _renderIconToBytes(IconData icon, {double size = 28, Color color = Colors.white}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontSize: size, fontFamily: icon.fontFamily, package: icon.fontPackage, color: color),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    painter.paint(canvas, Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.ceil(), size.ceil());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _showSkillResult() async {
    try {
      final waveformBytes = await _renderIconToBytes(Icons.graphic_eq);
      final micBytes = await _renderIconToBytes(Icons.mic, size: 16);
      final screenBytes = await _renderIconToBytes(Icons.desktop_mac, size: 16);
      final cursorBytes = await _renderIconToBytes(Icons.mouse, size: 16);

      await _plugin.showSkillResult(
        SkillResult(
          name: 'Dictation',
          icon: 'mic',
          iconBytes: waveformBytes,
          resultText:
              "Hi there! I'm Jay and I'm testing out Shadow's newest "
              "feature right now and it seems pretty cool! ",
          contexts: [
            SkillResultContext(type: 'sfSymbol', value: 'waveform', name: 'Microphone', iconBytes: micBytes),
            SkillResultContext(type: 'sfSymbol', value: 'display', name: 'Screen', iconBytes: screenBytes),
            SkillResultContext(type: 'sfSymbol', value: 'cursorarrow', name: 'Cursor', iconBytes: cursorBytes),
            const SkillResultContext(type: 'appIcon', value: 'com.google.Chrome', name: 'Google Chrome'),
          ],
        ),
      );
      _setStatus('SkillResult shown');
    } on PlatformException catch (e) {
      _setStatus('Failed: ${e.message}', isError: true);
    }
  }

  Future<void> _dismissSkillResult() async {
    try {
      await _plugin.dismissSkillResult();
      _setStatus('SkillResult dismissed');
    } on PlatformException catch (e) {
      _setStatus('Failed: ${e.message}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Skill Result', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton(onPressed: _showSkillResult, child: const Text('Show SkillResult')),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: _dismissSkillResult, child: const Text('Dismiss')),
          ],
        ),
        const SizedBox(height: 12),
        if (_status.isNotEmpty)
          Text(_status, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _isStatusError ? Colors.red : Colors.green)),
      ],
    );
  }
}
