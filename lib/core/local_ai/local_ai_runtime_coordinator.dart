import 'dart:async';
import 'dart:collection';

enum LocalAiWorkload { chat, speechToText, diffusion }

enum LocalAiRuntimePhase { idle, waiting, releasing, active, failed }

class LocalAiRuntimeState {
  LocalAiRuntimeState({
    required this.phase,
    required Set<LocalAiWorkload> activeWorkloads,
    this.requestedWorkload,
    this.exclusiveAccess,
    this.errorMessage,
  }) : activeWorkloads = UnmodifiableSetView(activeWorkloads);

  factory LocalAiRuntimeState.idle() => LocalAiRuntimeState(
    phase: LocalAiRuntimePhase.idle,
    activeWorkloads: const <LocalAiWorkload>{},
  );

  final LocalAiRuntimePhase phase;
  final Set<LocalAiWorkload> activeWorkloads;
  final LocalAiWorkload? requestedWorkload;
  final bool? exclusiveAccess;
  final String? errorMessage;
}

class LocalAiCoordinationException implements Exception {
  const LocalAiCoordinationException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'LocalAiCoordinationException: $message';
}

typedef LocalAiEvictionCallback = Future<void> Function();

/// A revocable ownership token for one heavyweight local-AI workload.
class LocalAiRuntimeLease {
  LocalAiRuntimeLease._({
    required LocalAiRuntimeCoordinator coordinator,
    required int id,
    required this.workload,
  }) : _coordinator = coordinator,
       _id = id;

  final LocalAiRuntimeCoordinator _coordinator;
  final int _id;
  final LocalAiWorkload workload;

  bool get isActive => _coordinator._isActive(_id);

  Future<void> release() async => _coordinator._release(_id);
}

class _ActiveLease {
  const _ActiveLease({
    required this.id,
    required this.workload,
    required this.onEvict,
  });

  final int id;
  final LocalAiWorkload workload;
  final LocalAiEvictionCallback onEvict;
}

/// Serializes heavyweight on-device runtimes on constrained Android devices.
///
/// A lease remains active for as long as its native runtime is resident. When
/// another workload needs exclusive access, the current owner's [onEvict]
/// callback is awaited before the next lease is granted. This ensures chat,
/// Whisper and diffusion do not overlap on the Android 4 GB profile.
class LocalAiRuntimeCoordinator {
  LocalAiRuntimeCoordinator({
    required Future<bool> Function() requiresExclusiveAccess,
  }) : _requiresExclusiveAccess = requiresExclusiveAccess;

  final Future<bool> Function() _requiresExclusiveAccess;
  final StreamController<LocalAiRuntimeState> _states =
      StreamController<LocalAiRuntimeState>.broadcast(sync: true);
  final Map<int, _ActiveLease> _active = <int, _ActiveLease>{};

  LocalAiRuntimeState _state = LocalAiRuntimeState.idle();
  Future<void> _operationTail = Future<void>.value();
  Future<bool>? _exclusiveAccess;
  int _nextLeaseId = 0;

  LocalAiRuntimeState get state => _state;
  Stream<LocalAiRuntimeState> get stream => _states.stream;

  Future<LocalAiRuntimeLease> acquire(
    LocalAiWorkload workload, {
    required LocalAiEvictionCallback onEvict,
  }) {
    final result = _operationTail.then(
      (_) => _acquire(workload, onEvict: onEvict),
    );
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<LocalAiRuntimeLease> _acquire(
    LocalAiWorkload workload, {
    required LocalAiEvictionCallback onEvict,
  }) async {
    _emit(
      LocalAiRuntimeState(
        phase: LocalAiRuntimePhase.waiting,
        activeWorkloads: _workloads,
        requestedWorkload: workload,
        exclusiveAccess: _state.exclusiveAccess,
      ),
    );

    final exclusive = await _resolveExclusiveAccess();
    if (exclusive && _active.isNotEmpty) {
      _emit(
        LocalAiRuntimeState(
          phase: LocalAiRuntimePhase.releasing,
          activeWorkloads: _workloads,
          requestedWorkload: workload,
          exclusiveAccess: true,
        ),
      );
      final residentLeases = _active.values.toList(growable: false);
      for (final resident in residentLeases) {
        try {
          await resident.onEvict();
        } catch (error) {
          _emit(
            LocalAiRuntimeState(
              phase: LocalAiRuntimePhase.failed,
              activeWorkloads: _workloads,
              requestedWorkload: workload,
              exclusiveAccess: true,
              errorMessage: 'Unable to release ${resident.workload.name}.',
            ),
          );
          throw LocalAiCoordinationException(
            'Unable to release ${resident.workload.name} before starting '
            '${workload.name}.',
            error,
          );
        }
        _active.remove(resident.id);
      }
    }

    final id = ++_nextLeaseId;
    _active[id] = _ActiveLease(id: id, workload: workload, onEvict: onEvict);
    _emit(
      LocalAiRuntimeState(
        phase: LocalAiRuntimePhase.active,
        activeWorkloads: _workloads,
        requestedWorkload: workload,
        exclusiveAccess: exclusive,
      ),
    );
    return LocalAiRuntimeLease._(coordinator: this, id: id, workload: workload);
  }

  Future<bool> _resolveExclusiveAccess() {
    return _exclusiveAccess ??= _requiresExclusiveAccess().catchError(
      (_) => true,
    );
  }

  bool _isActive(int id) => _active.containsKey(id);

  void _release(int id) {
    if (_active.remove(id) == null) return;
    _emit(
      LocalAiRuntimeState(
        phase: _active.isEmpty
            ? LocalAiRuntimePhase.idle
            : LocalAiRuntimePhase.active,
        activeWorkloads: _workloads,
        exclusiveAccess: _state.exclusiveAccess,
      ),
    );
  }

  Set<LocalAiWorkload> get _workloads =>
      _active.values.map((lease) => lease.workload).toSet();

  void _emit(LocalAiRuntimeState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  Future<void> close() => _states.close();
}

const int _androidExclusiveRamThresholdBytes = 5 * 1024 * 1024 * 1024;

/// Conservative 4 GB Android policy. Unknown RAM is treated as constrained so
/// a missing platform signal cannot expose the process to an avoidable OOM.
bool requiresExclusiveLocalAiAccess({
  required String platform,
  required int totalRamBytes,
}) {
  if (platform.toLowerCase() != 'android') return false;
  return totalRamBytes <= 0 ||
      totalRamBytes <= _androidExclusiveRamThresholdBytes;
}
