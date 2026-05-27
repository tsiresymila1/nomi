import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/database/gena_database.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/workspace/data/services/workspace_document_parser.dart';
import 'package:gena/features/workspace/presentation/cubit/workspace_config_cubit.dart';
import 'package:gena/features/workspace/presentation/cubit/workspace_config_state.dart';
import 'package:gena/features/workspace/presentation/widgets/workspace_config_form.dart';
import 'package:gena/features/workspace/presentation/workspace_presentation_service_locator.dart';
import 'package:gena/features/workspace/presentation/services/workspace_rag_ingestion_controller.dart';
import 'package:gena/features/workspace/data/cubits/workspace_embedder_install_cubit.dart';

class WorkspaceConfigPage extends StatelessWidget {
  const WorkspaceConfigPage({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context) {
    registerWorkspacePresentationDependencies();

    return BlocProvider<WorkspaceConfigCubit>(
      create: (_) => WorkspaceConfigCubit(
        workspaceId: workspaceId,
        database: sl<GenaDatabase>(),
        parser: sl<WorkspaceDocumentParser>(),
        ingestionController: sl<WorkspaceRagIngestionController>(),
        embedderCubit: sl<WorkspaceEmbedderInstallCubit>(),
      )..initialize(),
      child: BlocBuilder<WorkspaceConfigCubit, WorkspaceConfigState>(
        builder: (context, state) {
          if (state.workspaceLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state.workspaceNotFound) {
            return const Scaffold(
              body: Center(child: Text('Workspace not found')),
            );
          }

          final workspace = state.workspace!;
          return Scaffold(
            appBar: AppBar(
              title: Text(
                'Workspace Config · ${workspace.name}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            body: const WorkspaceConfigForm(),
          );
        },
      ),
    );
  }
}
