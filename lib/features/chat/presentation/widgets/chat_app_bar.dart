import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/chat/data/cubits/chat_ui_cubits.dart';
import 'package:gena/features/chat/data/providers/active_model_info_provider.dart';
import 'package:gena/features/chat/data/providers/chat_page_actions_provider.dart';
import 'package:gena/features/chat/presentation/widgets/chat_model_selection_sheet.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({super.key, required this.gradColor});

  final Color gradColor;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ModelInfo?>(
      stream: sl<ActiveModelInfoResolver>().watchActiveModelInfo(),
      builder: (context, snapshot) {
        final activeModel = snapshot.data;
        return BlocBuilder<ChatModelSwitchingCubit, bool>(
          bloc: sl<ChatModelSwitchingCubit>(),
          builder: (context, isSwitchingModel) {
            final modelLabel = _resolveModelLabel(
              activeModel,
              isSwitchingModel,
            );
            return AppBar(
              scrolledUnderElevation: 0,
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      gradColor.withAlpha(0),
                      gradColor.withAlpha(125),
                      gradColor.withAlpha(250),
                    ],
                  ),
                ),
              ),
              title: InkWell(
                onTap: () => _showModelSelector(context),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        modelLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded),
                  ],
                ),
              ),
              centerTitle: true,
              leading: Builder(
                builder: (context) {
                  return IconButton(
                    icon: const Icon(Icons.menu_rounded, size: 28),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  );
                },
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, size: 28),
                  onPressed: () => sl<ChatPageActions>().createNewThread(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showModelSelector(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => const SafeArea(child: ChatModelSelectionSheet()),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  String _resolveModelLabel(ModelInfo? activeModel, bool isModelLoading) {
    if (isModelLoading) {
      return 'Model loading...';
    }
    if (activeModel == null) {
      return 'No active model';
    }
    final providerLabel = activeModel.provider == 'remote' ? 'Remote' : 'Local';
    return '$providerLabel - ${activeModel.name}';
  }
}
