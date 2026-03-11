import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shadow_action_skill/shadow_action_skill.dart';

class AccessibilitySection extends StatefulWidget {
  const AccessibilitySection({super.key});

  @override
  State<AccessibilitySection> createState() => _AccessibilitySectionState();
}

class _AccessibilitySectionState extends State<AccessibilitySection> {
  final _plugin = ShadowActionSkill();

  String _status = '';
  bool _isStatusError = false;
  bool _isPermissionGranted = false;
  String _clipboardContent = '';
  String _copiedText = '';

  final _pasteController = TextEditingController();
  final List<HotKey> _hotKeys = [];

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _registerHotkeys();
  }

  @override
  void dispose() {
    for (final hotKey in _hotKeys) {
      hotKeyManager.unregister(hotKey);
    }
    _pasteController.dispose();
    super.dispose();
  }

  void _setStatus(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _status = message;
      _isStatusError = isError;
    });
  }

  // MARK: - Hotkeys

  void _registerHotkeys() {
    _registerHotkey(key: PhysicalKeyboardKey.keyC, modifiers: [HotKeyModifier.alt, HotKeyModifier.shift], handler: () => _copy());
    _registerHotkey(key: PhysicalKeyboardKey.keyA, modifiers: [HotKeyModifier.alt, HotKeyModifier.shift], handler: () => _copy(selectAll: true));
    _registerHotkey(key: PhysicalKeyboardKey.keyV, modifiers: [HotKeyModifier.alt, HotKeyModifier.shift], handler: () => _paste());
    _registerHotkey(key: PhysicalKeyboardKey.keyR, modifiers: [HotKeyModifier.alt, HotKeyModifier.shift], handler: () => _getClipboardContent());
    _registerHotkey(key: PhysicalKeyboardKey.keyW, modifiers: [HotKeyModifier.alt, HotKeyModifier.shift], handler: () => _setClipboardContent());
  }

  void _registerHotkey({required PhysicalKeyboardKey key, required List<HotKeyModifier> modifiers, required VoidCallback handler}) {
    final hotKey = HotKey(key: key, modifiers: modifiers, scope: HotKeyScope.system);
    hotKeyManager.register(hotKey, keyDownHandler: (_) => handler());
    _hotKeys.add(hotKey);
  }

  // MARK: - Permission

  Future<void> _checkPermission() async {
    try {
      final granted = await _plugin.checkAccessibilityPermission();
      if (!mounted) return;
      setState(() {
        _isPermissionGranted = granted;
      });
      _setStatus(granted ? 'Permission granted.' : 'Permission not granted.');
    } on PlatformException catch (e) {
      _setStatus('Failed to check permission: ${e.message}', isError: true);
    }
  }

  Future<void> _requestPermission() async {
    try {
      final granted = await _plugin.requestAccessibilityPermission();
      if (!mounted) return;
      setState(() {
        _isPermissionGranted = granted;
      });
      _setStatus(granted ? 'Permission granted.' : 'Permission not yet granted. Please enable in System Settings.');
    } on PlatformException catch (e) {
      _setStatus('Failed to request permission: ${e.message}', isError: true);
    }
  }

  // MARK: - Clipboard

  Future<void> _getClipboardContent() async {
    try {
      final content = await _plugin.getClipboardContent();
      if (!mounted) return;
      setState(() {
        _clipboardContent = content ?? '(empty)';
      });
      _setStatus('Clipboard read.');
    } on PlatformException catch (e) {
      _setStatus('Failed to read clipboard: ${e.message}', isError: true);
    }
  }

  Future<void> _setClipboardContent() async {
    final text = _pasteController.text;
    if (text.isEmpty) {
      _setStatus('Enter text to set clipboard.', isError: true);
      return;
    }
    try {
      await _plugin.setClipboardContent(text);
      _setStatus('Clipboard set to: "$text"');
    } on PlatformException catch (e) {
      _setStatus('Failed to set clipboard: ${e.message}', isError: true);
    }
  }

  // MARK: - Copy / Paste

  Future<void> _copy({bool selectAll = false}) async {
    try {
      final text = await _plugin.copy(selectAll: selectAll);
      if (!mounted) return;
      setState(() {
        _copiedText = text;
      });
      _setStatus('Copied: "${text.length > 80 ? '${text.substring(0, 80)}...' : text}"');
    } on PlatformException catch (e) {
      _setStatus('Copy failed: ${e.message}', isError: true);
    }
  }

  Future<void> _paste() async {
    final text = _pasteController.text;
    if (text.isEmpty) {
      _setStatus('Enter text to paste.', isError: true);
      return;
    }
    try {
      await _plugin.paste(text);
      _setStatus('Pasted: "$text"');
    } on PlatformException catch (e) {
      _setStatus('Paste failed: ${e.message}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Accessibility', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),

        // Permission
        Row(
          children: [
            Icon(_isPermissionGranted ? Icons.check_circle : Icons.warning, color: _isPermissionGranted ? Colors.green : Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text(_isPermissionGranted ? 'Accessibility: Granted' : 'Accessibility: Not Granted', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton(onPressed: _checkPermission, child: const Text('Check Permission')),
            ElevatedButton(onPressed: _requestPermission, child: const Text('Request Permission')),
          ],
        ),
        const SizedBox(height: 20),

        // Clipboard
        Text('Clipboard', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton(onPressed: _getClipboardContent, child: const Text('Read Clipboard')),
            ElevatedButton(onPressed: _setClipboardContent, child: const Text('Set Clipboard')),
          ],
        ),
        const SizedBox(height: 8),
        if (_clipboardContent.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: Text('Clipboard: $_clipboardContent', style: Theme.of(context).textTheme.bodyMedium),
          ),
        const SizedBox(height: 20),

        // Copy / Paste
        Text('Copy & Paste', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton(onPressed: () => _copy(), child: const Text('Copy (Cmd+C)')),
            ElevatedButton(onPressed: () => _copy(selectAll: true), child: const Text('Select All + Copy')),
            ElevatedButton(onPressed: _paste, child: const Text('Paste Text')),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 400,
          child: TextField(
            controller: _pasteController,
            decoration: const InputDecoration(labelText: 'Text to paste / set clipboard', border: OutlineInputBorder(), isDense: true),
          ),
        ),
        const SizedBox(height: 8),
        if (_copiedText.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: Text('Last copied: $_copiedText', style: Theme.of(context).textTheme.bodyMedium),
          ),
        const SizedBox(height: 12),

        // Status
        if (_status.isNotEmpty)
          Text(_status, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _isStatusError ? Colors.red : Colors.green)),
        const SizedBox(height: 20),

        // Hotkeys reference
        Text('Hotkeys (system-wide)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        const Text('\u2325\u21E7C \u2014 Copy', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const Text('\u2325\u21E7A \u2014 Select All + Copy', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const Text('\u2325\u21E7V \u2014 Paste', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const Text('\u2325\u21E7R \u2014 Read Clipboard', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const Text('\u2325\u21E7W \u2014 Set Clipboard', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
