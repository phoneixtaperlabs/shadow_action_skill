/// Available ASR engine providers.
enum AsrProvider {
  whisper,
  parakeet;

  /// Wire name sent to the native platform channel.
  String get channelName => name;
}

/// Configuration for starting a dictation session.
class DictationConfig {
  /// ASR engine to use. Defaults to [AsrProvider.whisper].
  final AsrProvider asrProvider;

  const DictationConfig({this.asrProvider = AsrProvider.whisper});

  Map<String, dynamic> toMap() => {'asrProvider': asrProvider.channelName};
}
