import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadow_action_skill/shadow_action_skill.dart';

class SkillSearchSection extends StatefulWidget {
  const SkillSearchSection({super.key});

  @override
  State<SkillSearchSection> createState() => _SkillSearchSectionState();
}

class _SkillSearchSectionState extends State<SkillSearchSection> {
  final _plugin = ShadowActionSkill();

  String _status = '';
  bool _isStatusError = false;

  Future<Uint8List> _renderIconToBytes(
    IconData icon, {
    double size = 40,
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

  @override
  void initState() {
    super.initState();
    _plugin.setNativeCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (!mounted) return;
    switch (call.method) {
      case 'onSkillSearchSelected':
        final args = call.arguments as Map<dynamic, dynamic>;
        final skillId = args['skillId'] as String?;
        final shortcut = args['shortcut'] as String?;
        _setStatus('Skill selected: $skillId (shortcut: $shortcut)');
    }
  }

  void _setStatus(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _status = message;
      _isStatusError = isError;
    });
  }

  Future<void> _showSkillSearch() async {
    try {
      final micBytes = await _renderIconToBytes(Icons.mic);
      final boltBytes = await _renderIconToBytes(Icons.flash_on);
      final sparkleBytes = await _renderIconToBytes(Icons.auto_awesome);

      final skills = [
        SkillSearchSkill(id: 'dictation', name: 'Dictation', icon: 'waveform', shortcut: '⌘Q', iconBytes: micBytes),
        SkillSearchSkill(id: 'quick_action', name: 'Quick Action', icon: 'bolt.fill', shortcut: '⌘W', iconBytes: boltBytes),
        SkillSearchSkill(id: 'ai_assist', name: 'Polish my write', icon: 'sparkles', shortcut: '⌘E', iconBytes: sparkleBytes),
        const SkillSearchSkill(id: 'screenshot', name: 'Screenshot', icon: 'camera.fill', shortcut: '⌘T'),
        const SkillSearchSkill(id: 'translate', name: 'Translate', icon: 'globe', shortcut: '⌘Y'),
        const SkillSearchSkill(id: 'summarize', name: 'Summarize', icon: 'doc.text', shortcut: '⌘U'),
        const SkillSearchSkill(id: 'grammar', name: 'Fix Grammar', icon: 'textformat.abc', shortcut: '⌘I'),
        const SkillSearchSkill(id: 'email', name: 'Draft Email', icon: 'envelope.fill', shortcut: '⌘O'),
        const SkillSearchSkill(id: 'code', name: 'Write Code', icon: 'chevron.left.forwardslash.chevron.right', shortcut: '⌘P'),
        const SkillSearchSkill(id: 'calendar', name: 'Schedule Event', icon: 'calendar', shortcut: '⇧⌘Q'),
        const SkillSearchSkill(id: 'notes', name: 'Quick Note', icon: 'note.text', shortcut: '⇧⌘W'),
        const SkillSearchSkill(id: 'reminder', name: 'Set Reminder', icon: 'bell.fill', shortcut: '⇧⌘E'),
      ];

      await _plugin.showSkillSearch(skills);
      _setStatus('SkillSearch shown');
    } on PlatformException catch (e) {
      _setStatus('Failed: ${e.message}', isError: true);
    }
  }

  Future<void> _dismissSkillSearch() async {
    try {
      await _plugin.dismissSkillSearch();
      _setStatus('SkillSearch dismissed');
    } on PlatformException catch (e) {
      _setStatus('Failed: ${e.message}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Skill Search', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton(
              onPressed: _showSkillSearch,
              child: const Text('Show SkillSearch'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _dismissSkillSearch,
              child: const Text('Dismiss'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_status.isNotEmpty)
          Text(
            _status,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _isStatusError ? Colors.red : Colors.green,
            ),
          ),
      ],
    );
  }
}
