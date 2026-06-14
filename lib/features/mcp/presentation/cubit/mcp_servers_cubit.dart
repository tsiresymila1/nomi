import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/logger.dart';
import 'package:gena/features/mcp/data/mcp_repository.dart';
import 'package:gena/features/mcp/data/models/mcp_server.dart';

class McpServersState {
  const McpServersState({
    this.servers = const [],
    this.loading = true,
    this.busy = false,
    this.errorMessage,
  });

  final List<McpServer> servers;
  final bool loading;
  final bool busy;
  final String? errorMessage;

  McpServersState copyWith({
    List<McpServer>? servers,
    bool? loading,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
  }) {
    return McpServersState(
      servers: servers ?? this.servers,
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class McpServersCubit extends Cubit<McpServersState> {
  McpServersCubit({required McpRepository repository})
    : _repository = repository,
      super(const McpServersState()) {
    _subscription = _repository.watchServers().listen(
      (servers) {
        emit(
          state.copyWith(servers: servers, loading: false, clearError: true),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        logger.e(error, error: error, stackTrace: stackTrace);
        emit(
          state.copyWith(
            loading: false,
            errorMessage: 'Failed to load MCP servers: $error',
          ),
        );
      },
    );
  }

  final McpRepository _repository;
  StreamSubscription<List<McpServer>>? _subscription;

  Future<void> addOrUpdateServer({
    int? id,
    required String name,
    required String url,
    String? authHeader,
    bool enabled = true,
  }) async {
    if (id == null) {
      await _repository.addServer(
        name: name.trim(),
        url: url.trim(),
        authHeader: authHeader,
        enabled: enabled,
      );
    } else {
      await _repository.updateServer(
        id: id,
        name: name.trim(),
        url: url.trim(),
        authHeader: authHeader,
        enabled: enabled,
      );
    }
  }

  Future<void> setEnabled(McpServer server, bool enabled) {
    return _repository.setEnabled(id: server.id, enabled: enabled);
  }

  Future<void> removeServer(McpServer server) {
    return _repository.deleteServer(server.id);
  }

  Future<T> runBusyTask<T>(Future<T> Function() task) async {
    if (state.busy) {
      throw StateError('Another MCP server operation is already running.');
    }
    emit(state.copyWith(busy: true, clearError: true));
    try {
      return await task();
    } catch (error, stackTrace) {
      logger.e(error, error: error, stackTrace: stackTrace);
      emit(state.copyWith(errorMessage: '$error'));
      rethrow;
    } finally {
      emit(state.copyWith(busy: false));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
