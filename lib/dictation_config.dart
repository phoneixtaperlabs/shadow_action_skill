/// Available ASR engine providers.
enum AsrProvider {
  whisper,
  parakeet;

  /// Wire name sent to the native platform channel.
  String get channelName => name;
}

/// Available Whisper GGML model files.
///
/// The [channelName] is sent over the platform channel and must match the file
/// present in `~/Library/Application Support/com.taperlabs.shadow/shared/`.
enum WhisperModel {
  smallQ5_1('ggml-small-q5_1.bin'),
  largeV3TurboQ5_0('ggml-large-v3-turbo-q5_0.bin');

  const WhisperModel(this.channelName);

  /// Wire name sent to the native platform channel (the model filename).
  final String channelName;
}

/// Configuration for starting a dictation session.
class DictationConfig {
  /// ASR engine to use. Defaults to [AsrProvider.whisper].
  final AsrProvider asrProvider;

  /// Whisper model to load. Null uses the native default ([WhisperModel.smallQ5_1]).
  /// Only valid when [asrProvider] is [AsrProvider.whisper].
  final WhisperModel? whisperModel;

  const DictationConfig({this.asrProvider = AsrProvider.whisper, this.whisperModel})
    : assert(whisperModel == null || asrProvider == AsrProvider.whisper, 'whisperModel is only valid when asrProvider is AsrProvider.whisper');

  Map<String, dynamic> toMap() => {
    'asrProvider': asrProvider.channelName,
    if (asrProvider == AsrProvider.whisper && whisperModel != null) 'whisperModelName': whisperModel!.channelName,
  };
}
