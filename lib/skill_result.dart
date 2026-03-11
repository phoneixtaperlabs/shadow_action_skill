import 'dart:typed_data';

/// Data for displaying a skill result overlay.
class SkillResult {
  /// Display name of the skill (e.g. `"Dictation"`).
  final String name;

  /// SF Symbol name for the skill icon.
  final String icon;

  /// PNG image bytes. Preferred over [icon] when present.
  final Uint8List? iconBytes;

  /// The result text to display.
  final String resultText;

  /// Context items shown below the result (e.g. microphone, screen, app).
  final List<SkillResultContext> contexts;

  const SkillResult({
    required this.name,
    required this.icon,
    this.iconBytes,
    required this.resultText,
    this.contexts = const [],
  });

  Map<String, dynamic> toMap() => {
    'skillName': name,
    'skillIcon': icon,
    if (iconBytes != null) 'skillIconBytes': iconBytes,
    'resultText': resultText,
    'contexts': contexts.map((c) => c.toMap()).toList(),
  };
}

/// A context item shown in the skill result overlay.
class SkillResultContext {
  /// `"sfSymbol"` or `"appIcon"`.
  final String type;

  /// SF Symbol name (when type is `"sfSymbol"`) or app bundle ID (when `"appIcon"`).
  final String value;

  /// Tooltip label (e.g. `"Microphone"`, `"Google Chrome"`).
  final String name;

  /// PNG image bytes. When present, rendered instead of SF Symbol / app icon.
  final Uint8List? iconBytes;

  const SkillResultContext({
    required this.type,
    required this.value,
    required this.name,
    this.iconBytes,
  });

  Map<String, dynamic> toMap() => {
    'type': type,
    'name': name,
    'value': value,
    if (iconBytes != null) 'iconBytes': iconBytes,
  };
}
