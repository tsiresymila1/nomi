import 'package:gena/core/database/gena_database.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/chat/presentation/cubit/native_tool_execution_cubit.dart';
import 'package:gena/features/mcp/data/mcp_repository.dart';
import 'package:gena/features/mcp/data/services/mcp_client_manager.dart';
import 'package:gena/features/mcp/data/services/mcp_dart_client_manager.dart';
import 'package:gena/features/mcp/data/services/mcp_tool_actions_service.dart';
import 'package:gena/features/mcp/presentation/cubit/mcp_servers_cubit.dart';

void registerMcpDependencies() {
  if (!sl.isRegistered<McpRepository>()) {
    sl.registerLazySingleton<McpRepository>(
      () => McpRepository(database: sl<GenaDatabase>()),
    );
  }
  if (!sl.isRegistered<McpClientManager>()) {
    sl.registerLazySingleton<McpClientManager>(McpDartClientManager.new);
  }
  if (!sl.isRegistered<McpToolActions>()) {
    sl.registerLazySingleton<McpToolActions>(
      () => McpToolActions(
        clientManager: sl<McpClientManager>(),
        executionCubit: sl<NativeToolExecutionCubit>(),
      ),
    );
  }
  if (!sl.isRegistered<McpServersCubit>()) {
    sl.registerLazySingleton<McpServersCubit>(
      () => McpServersCubit(repository: sl<McpRepository>()),
    );
  }
}
