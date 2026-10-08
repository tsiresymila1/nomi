import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/features/chat/data/models/whisper_model_profile.dart';
import 'package:gena/features/chat/presentation/cubit/whisper_model_cubit.dart';

class WhisperModelSettingsSection extends StatelessWidget {
  const WhisperModelSettingsSection({super.key, required this.cubit});

  final WhisperModelCubit cubit;

  Future<void> _select(
    BuildContext context,
    WhisperModelProfile profile,
  ) async {
    if (profile == cubit.state.profile) return;
    if (profile == WhisperModelProfile.base) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Use the Base Whisper model?'),
          content: const Text(
            'Base can improve transcription accuracy, but it downloads more '
            'data and uses more memory. Tiny is recommended for 4 GB devices.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Use Base'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await cubit.selectProfile(profile);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WhisperModelCubit, WhisperModelState>(
      bloc: cubit,
      builder: (context, state) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ListTile(
                  leading: Icon(Icons.graphic_eq_rounded),
                  title: Text('Voice & audio'),
                  subtitle: Text(
                    'Choose the local multilingual Whisper model.',
                  ),
                ),
                _WhisperProfileTile(
                  key: const ValueKey('whisper-profile-tiny'),
                  profile: WhisperModelProfile.tiny,
                  selected: state.profile == WhisperModelProfile.tiny,
                  subtitle: 'Recommended for 4 GB · about 75 MB',
                  onTap: () => _select(context, WhisperModelProfile.tiny),
                ),
                _WhisperProfileTile(
                  key: const ValueKey('whisper-profile-base'),
                  profile: WhisperModelProfile.base,
                  selected: state.profile == WhisperModelProfile.base,
                  subtitle: 'Better accuracy · about 142 MB',
                  onTap: () => _select(context, WhisperModelProfile.base),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WhisperProfileTile extends StatelessWidget {
  const _WhisperProfileTile({
    super.key,
    required this.profile,
    required this.selected,
    required this.subtitle,
    required this.onTap,
  });

  final WhisperModelProfile profile;
  final bool selected;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text('${profile.label} (multilingual)'),
      subtitle: Text(subtitle),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
    );
  }
}
