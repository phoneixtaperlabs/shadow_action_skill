import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadow_action_skill/shadow_action_skill.dart';

class QuickAccessSection extends StatefulWidget {
  const QuickAccessSection({super.key});

  @override
  State<QuickAccessSection> createState() => _QuickAccessSectionState();
}

class _QuickAccessSectionState extends State<QuickAccessSection> {
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
      case 'onQuickAccessSkillSelected':
        final args = call.arguments as Map<dynamic, dynamic>;
        final skillId = args['skillId'] as String?;
        final key = args['key'] as String?;
        _setStatus('Skill selected: $skillId (key: $key)');
    }
  }

  void _setStatus(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _status = message;
      _isStatusError = isError;
    });
  }

  Future<Uint8List> _renderIconToBytes(
    IconData icon, {
    double size = 28,
    Color color = Colors.white,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
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

  Future<void> _showQuickAccess() async {
    try {
      final micBytes = await _renderIconToBytes(Icons.mic);
      final boltBytes = await _renderIconToBytes(Icons.flash_on);
      final sparkleBytes = await _renderIconToBytes(Icons.auto_awesome);

      final skills = [
        QuickAccessSkill(id: 'dictation', name: 'Dictation', key: 'Q', icon: 'waveform', iconBytes: micBytes),
        QuickAccessSkill(id: 'quick_action', name: 'Quick Action', key: 'W', icon: 'bolt.fill', iconBytes: boltBytes),
        QuickAccessSkill(id: 'ai_assist', name: 'Polish my write', key: 'E', icon: 'sparkles', iconBytes: sparkleBytes),
      ];

      await _plugin.showQuickAccess(skills);
      _setStatus('QuickAccess shown');
    } on PlatformException catch (e) {
      _setStatus('Failed: ${e.message}', isError: true);
    }
  }

  Future<void> _dismissQuickAccess() async {
    try {
      await _plugin.dismissQuickAccess();
      _setStatus('QuickAccess dismissed');
    } on PlatformException catch (e) {
      _setStatus('Failed: ${e.message}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Access', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton(onPressed: _showQuickAccess, child: const Text('Show QuickAccess')),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: _dismissQuickAccess, child: const Text('Dismiss')),
          ],
        ),
        const SizedBox(height: 12),
        if (_status.isNotEmpty)
          Text(_status, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _isStatusError ? Colors.red : Colors.green)),
      ],
    );
  }
}
