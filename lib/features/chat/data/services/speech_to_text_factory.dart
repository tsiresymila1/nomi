import 'package:gena/features/chat/data/models/whisper_model_profile.dart';

import 'speech_to_text.dart';
import 'whisper_model_provisioner.dart';
// Selects the native whisper driver where dart:io is available, and the
// unsupported driver on web.
import 'unsupported_speech_to_text.dart'
    if (dart.library.io) 'whisper_speech_to_text.dart'
    as impl;

/// Returns the speech-to-text driver for the current platform.
SpeechToText createSpeechToText({
  required WhisperProvisioner provisioner,
  required WhisperModelProfile Function() selectedProfile,
}) => impl.createSpeechToText(
  provisioner: provisioner,
  selectedProfile: selectedProfile,
);
