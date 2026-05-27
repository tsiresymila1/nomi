import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/core/toast/app_toast.dart';
import 'package:gena/features/downloads/data/models/model_info.dart';
import 'package:gena/features/downloads/data/models/model_provider_type.dart';
import 'package:gena/features/downloads/data/model_repository.dart';
import 'package:gena/features/downloads/presentation/widgets/model_backend_section.dart';
import 'package:gena/features/downloads/presentation/widgets/model_basic_info_section.dart';
import 'package:gena/features/downloads/presentation/widgets/model_capability_switches.dart';
import 'package:gena/features/downloads/presentation/widgets/model_remote_api_section.dart';
import 'package:gena/features/downloads/presentation/widgets/model_settings_section.dart';
import 'package:gena/features/downloads/presentation/widgets/model_source_section.dart';
import 'package:path_provider/path_provider.dart';

part 'add_model_page_state.dart';

class AddModelPage extends StatefulWidget {
  final ModelInfo? initialModel;

  const AddModelPage({super.key, this.initialModel});

  @override
  State<AddModelPage> createState() => _AddModelPageState();
}
