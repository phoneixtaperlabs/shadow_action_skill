import 'dart:typed_data';

/// A skill entry in the quick access popup.
class QuickAccessSkill {
  /// Unique skill identifier.
  final String id;

  /// Display name shown on hover.
  final String name;

  /// Shortcut key label (e.g. `"Q"`).
  final String key;

  /// SF Symbol name, used as fallback when [iconBytes] is `null`.
  final String? icon;

  /// PNG image bytes. Preferred over [icon] when present.
  final Uint8List? iconBytes;

  const QuickAccessSkill({
    required this.id,
    required this.name,
    required this.key,
    this.icon,
    this.iconBytes,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'key': key,
    if (icon != null) 'icon': icon,
    if (iconBytes != null) 'iconBytes': iconBytes,
  };
}
