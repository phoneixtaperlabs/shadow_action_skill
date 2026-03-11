import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadow_action_skill/shadow_action_skill.dart';

class ScreenshotSection extends StatefulWidget {
  const ScreenshotSection({super.key});

  @override
  State<ScreenshotSection> createState() => _ScreenshotSectionState();
}

class _ScreenshotSectionState extends State<ScreenshotSection> {
  final _plugin = ShadowActionSkill();

  String _status = '';
  bool _isStatusError = false;
  String _screenshotPath = '';
  int _timestamp = 0;
  double _quality = 0.8;
  bool _isCapturing = false;

  void _setStatus(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _status = message;
      _isStatusError = isError;
    });
  }

  Future<void> _captureScreenshot() async {
    setState(() {
      _isCapturing = true;
    });
    try {
      // Show glow overlay and capture screenshot simultaneously
      final results = await Future.wait([_plugin.showGlowOverlay(), _plugin.captureScreenshot(quality: _quality)]);
      final screenshotResult = results[1] as Map<String, dynamic>;

      debugPrint("screenshotResult : $screenshotResult");

      // Dismiss glow overlay after 2 seconds
      Future.delayed(const Duration(seconds: 2), () => _plugin.dismissGlowOverlay());

      if (!mounted) return;
      setState(() {
        _screenshotPath = screenshotResult['filePath'] as String? ?? '';
        _timestamp = screenshotResult['timestamp'] as int? ?? 0;
        _isCapturing = false;
      });
      _setStatus('Screenshot captured.');
    } on PlatformException catch (e) {
      _plugin.dismissGlowOverlay();
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
      });
      _setStatus('Capture failed: ${e.message}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Screenshot', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),

        // Quality slider
        Row(
          children: [
            Text('Quality: ${_quality.toStringAsFixed(1)}', style: Theme.of(context).textTheme.bodyMedium),
            Expanded(
              child: Slider(
                value: _quality,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                label: _quality.toStringAsFixed(1),
                onChanged: (value) {
                  setState(() {
                    _quality = value;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Capture button
        ElevatedButton(onPressed: _isCapturing ? null : _captureScreenshot, child: Text(_isCapturing ? 'Capturing...' : 'Capture Screenshot')),
        const SizedBox(height: 12),

        // Status
        if (_status.isNotEmpty)
          Text(_status, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: _isStatusError ? Colors.red : Colors.green)),
        const SizedBox(height: 8),

        // Result info
        if (_screenshotPath.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Path: $_screenshotPath', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  'Timestamp: $_timestamp (${DateTime.fromMillisecondsSinceEpoch(_timestamp * 1000)})',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Image preview
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_screenshotPath), width: double.infinity, fit: BoxFit.contain)),
        ],
      ],
    );
  }
}
