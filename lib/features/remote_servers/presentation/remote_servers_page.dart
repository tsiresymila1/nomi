import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/remote_servers/data/providers/remote_server_providers.dart';
import 'package:gena/features/remote_servers/presentation/widgets/remote_servers_view.dart';

class RemoteServersPage extends StatelessWidget {
  const RemoteServersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<RemoteServersCubit>(),
      child: const RemoteServersView(),
    );
  }
}
