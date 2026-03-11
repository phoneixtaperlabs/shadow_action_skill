import 'dart:typed_data';

/// A skill entry in the skill search overlay.
class SkillSearchSkill {
  /// Unique skill identifier.
  final String id;

  /// Display name shown in the row.
  final String name;

  /// SF Symbol name, used as fallback when [iconBytes] is `null`.
  final String? icon;

  /// Keyboard shortcut display (e.g. `"⌘Q"`).
  final String shortcut;

  /// PNG image bytes. Preferred over [icon] when present.
  final Uint8List? iconBytes;

  const SkillSearchSkill({
    required this.id,
    required this.name,
    this.icon,
    required this.shortcut,
    this.iconBytes,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'shortcut': shortcut,
    if (icon != null) 'icon': icon,
    if (iconBytes != null) 'iconBytes': iconBytes,
  };
}
