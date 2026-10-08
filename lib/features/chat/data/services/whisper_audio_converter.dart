import 'unsupported_whisper_audio_converter.dart'
    if (dart.library.io) 'native_whisper_audio_converter.dart'
    as impl;

void registerWhisperAudioConverter() => impl.registerWhisperAudioConverter();
