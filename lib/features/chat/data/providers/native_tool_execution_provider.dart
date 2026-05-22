import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gena/features/chat/data/models/native_tool_request.dart';

class NativeToolExecutionState {
  final NativeToolRequest? currentRequest;

  const NativeToolExecutionState({required this.currentRequest});

  const NativeToolExecutionState.idle() : this(currentRequest: null);
}

final nativeToolExecutionProvider =
    NotifierProvider<NativeToolExecutionNotifier, NativeToolExecutionState>(
      NativeToolExecutionNotifier.new,
    );

class NativeToolExecutionNotifier extends Notifier<NativeToolExecutionState> {
  final List<NativeToolRequest> _queue = <NativeToolRequest>[];
  final Map<String, Completer<bool>> _pending = <String, Completer<bool>>{};

  @override
  NativeToolExecutionState build() => const NativeToolExecutionState.idle();

  Future<bool> requestApproval(NativeToolRequest request) {
    final completer = Completer<bool>();
    _pending[request.id] = completer;
    _queue.add(request);
    _promoteNext();
    return completer.future;
  }

  void approveCurrent() {
    final current = state.currentRequest;
    if (current == null) return;
    _resolve(current.id, true);
  }

  void rejectCurrent() {
    final current = state.currentRequest;
    if (current == null) return;
    _resolve(current.id, false);
  }

  void _resolve(String id, bool approved) {
    final completer = _pending.remove(id);
    if (completer != null && !completer.isCompleted) {
      completer.complete(approved);
    }
    if (_queue.isNotEmpty && _queue.first.id == id) {
      _queue.removeAt(0);
    } else {
      _queue.removeWhere((item) => item.id == id);
    }
    state = const NativeToolExecutionState.idle();
    _promoteNext();
  }

  void _promoteNext() {
    if (state.currentRequest != null) return;
    if (_queue.isEmpty) return;
    state = NativeToolExecutionState(currentRequest: _queue.first);
  }
}
