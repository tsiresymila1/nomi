import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/mcp/presentation/cubit/mcp_servers_cubit.dart';
import 'package:gena/features/mcp/presentation/widgets/mcp_servers_view.dart';

class McpServersPage extends StatelessWidget {
  const McpServersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<McpServersCubit>(),
      child: const McpServersView(),
    );
  }
}
