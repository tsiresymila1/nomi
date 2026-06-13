import 'local_model_runtime.dart';
// Selects the native llamadart runtime where dart:io is available, and the
// unsupported runtime on web.
import 'unsupported_local_model_runtime.dart'
    if (dart.library.io) 'llamadart_local_model_runtime.dart'
    as impl;

/// Returns the local model runtime for the current platform.
LocalModelRuntime createLocalModelRuntime() => impl.createLocalModelRuntime();
