import 'speech_to_text.dart';
// Selects the native whisper driver where dart:io is available, and the
// unsupported driver on web.
import 'unsupported_speech_to_text.dart'
    if (dart.library.io) 'whisper_speech_to_text.dart'
    as impl;

/// Returns the speech-to-text driver for the current platform.
SpeechToText createSpeechToText() => impl.createSpeechToText();
