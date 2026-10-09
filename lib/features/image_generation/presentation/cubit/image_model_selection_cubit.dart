import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:gena/features/image_generation/data/models/image_generation_models.dart';
import 'package:gena/features/image_generation/data/models/image_model_catalog.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

class ImageModelSelectionState {
  const ImageModelSelectionState({
    this.selectedId = ImageModelCatalog.sdxsId,
    this.customProfiles = const <ImageModelProfile>[],
  });

  final String selectedId;
  final List<ImageModelProfile> customProfiles;

  List<ImageModelProfile> get allProfiles => <ImageModelProfile>[
    ...ImageModelCatalog.builtIn,
    ...customProfiles,
  ];

  ImageModelProfile get selectedProfile {
    for (final profile in allProfiles) {
      if (profile.id == selectedId) return profile;
    }
    return ImageModelCatalog.sdxs;
  }

  ImageModelSelectionState copyWith({
    String? selectedId,
    List<ImageModelProfile>? customProfiles,
  }) {
    return ImageModelSelectionState(
      selectedId: selectedId ?? this.selectedId,
      customProfiles: customProfiles ?? this.customProfiles,
    );
  }
}

class ImageModelSelectionCubit extends HydratedCubit<ImageModelSelectionState> {
  ImageModelSelectionCubit() : super(const ImageModelSelectionState());

  void select(String id) {
    if (!state.allProfiles.any((profile) => profile.id == id)) {
      throw ArgumentError.value(id, 'id', 'Unknown image model profile');
    }
    if (state.selectedId == id) return;
    emit(state.copyWith(selectedId: id));
  }

  ImageModelProfile registerExternal({
    required String name,
    required String filePath,
    required int sizeBytes,
    int steps = 20,
    double guidanceScale = 7,
  }) {
    final normalizedPath = _normalizePath(filePath);
    final id = 'custom:${sha256.convert(utf8.encode(normalizedPath))}';
    final profile = ImageModelProfile.external(
      id: id,
      name: name.trim(),
      filePath: normalizedPath,
      sizeBytes: sizeBytes,
      steps: steps,
      guidanceScale: guidanceScale,
    );
    final profiles = <ImageModelProfile>[
      for (final existing in state.customProfiles)
        if (existing.id != id) existing,
      profile,
    ];
    emit(state.copyWith(customProfiles: List.unmodifiable(profiles)));
    return profile;
  }

  void removeCustom(String id) {
    final profiles = state.customProfiles
        .where((profile) => profile.id != id)
        .toList(growable: false);
    if (profiles.length == state.customProfiles.length) return;
    emit(
      ImageModelSelectionState(
        selectedId: state.selectedId == id
            ? ImageModelCatalog.sdxsId
            : state.selectedId,
        customProfiles: profiles,
      ),
    );
  }

  @override
  ImageModelSelectionState? fromJson(Map<String, dynamic> json) {
    final rawProfiles = json['customProfiles'];
    final customProfiles = <ImageModelProfile>[];
    if (rawProfiles is List) {
      for (final raw in rawProfiles) {
        if (raw is! Map) continue;
        try {
          final profile = ImageModelProfile.fromJson(
            Map<String, dynamic>.from(raw),
          );
          if (profile.isExternal) customProfiles.add(profile);
        } catch (_) {
          // Ignore one corrupt custom entry and restore the remaining catalog.
        }
      }
    }
    final selectedId = json['selectedId'] as String?;
    final isKnown =
        selectedId != null &&
        (ImageModelCatalog.findBuiltIn(selectedId) != null ||
            customProfiles.any((profile) => profile.id == selectedId));
    return ImageModelSelectionState(
      selectedId: isKnown ? selectedId : ImageModelCatalog.sdxsId,
      customProfiles: List.unmodifiable(customProfiles),
    );
  }

  @override
  Map<String, dynamic>? toJson(ImageModelSelectionState state) {
    return <String, dynamic>{
      'selectedId': state.selectedId,
      'customProfiles': state.customProfiles
          .map((profile) => profile.toJson())
          .toList(growable: false),
    };
  }
}

String _normalizePath(String path) {
  final trimmed = path.trim().replaceAll('\\', '/');
  return Uri(path: trimmed).normalizePath().path;
}
