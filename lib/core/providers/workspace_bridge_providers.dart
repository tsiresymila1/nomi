import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/workspace/data/services/workspace_actions.dart';
import 'package:gena/features/workspace/data/services/workspace_queries_service.dart';

/// Convenience getters for workspace services previously exposed as Riverpod providers.
/// Use sl<WorkspaceActions>() directly for new code.
WorkspaceActions get workspaceActions => sl<WorkspaceActions>();
WorkspaceQueriesService get workspaceQueriesService =>
    sl<WorkspaceQueriesService>();
