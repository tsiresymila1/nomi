# Graph Report - gena  (2026-05-17)

## Corpus Check
- 103 files · ~78,892 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 660 nodes · 794 edges · 67 communities (52 shown, 15 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 8 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `51795239`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter_riverpod/flutter_riverpod.dart` - 37 edges
2. `package:flutter/material.dart` - 28 edges
3. `_` - 20 edges
4. `package:flutter_gemma/flutter_gemma.dart` - 16 edges
5. `Nomi` - 11 edges
6. `package:gena/features/downloads/data/model_repository.dart` - 9 edges
7. `_` - 9 edges
8. `_` - 9 edges
9. `package:gena/features/chat/data/providers/chat_provider.dart` - 9 edges
10. `_` - 9 edges

## Surprising Connections (you probably didn't know these)
- `main()` --calls--> `my_application_new()`  [INFERRED]
  linux/runner/main.cc → linux/runner/my_application.cc
- `my_application_activate()` --calls--> `fl_register_plugins()`  [INFERRED]
  linux/runner/my_application.cc → linux/flutter/generated_plugin_registrant.cc
- `OnCreate()` --calls--> `GetClientArea()`  [INFERRED]
  windows/runner/flutter_window.cpp → windows/runner/win32_window.cpp
- `OnCreate()` --calls--> `RegisterPlugins()`  [INFERRED]
  windows/runner/flutter_window.cpp → windows/flutter/generated_plugin_registrant.cc
- `OnCreate()` --calls--> `SetChildContent()`  [INFERRED]
  windows/runner/flutter_window.cpp → windows/runner/win32_window.cpp

## Communities (67 total, 15 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.05
Nodes (42): dart:math, package:drift/drift.dart, package:drift_flutter/drift_flutter.dart, package:flutter_riverpod/flutter_riverpod.dart, package:gena/core/database/gena_database.dart, package:gena/core/database/gena_provider.dart, package:gena/core/logger.dart, package:gena/features/chat/data/models/gemma_chat_session.dart (+34 more)

### Community 1 - "Community 1"
Cohesion: 0.04
Nodes (39): package:flutter/material.dart, package:flutter_test/flutter_test.dart, package:fluttertoast/fluttertoast.dart, package:gena/features/downloads/data/providers/download_notifier.dart, package:gena/features/downloads/presentation/widgets/download_item.dart, package:gena/main.dart, _appBarTheme, AppTheme (+31 more)

### Community 2 - "Community 2"
Cohesion: 0.05
Nodes (40): package:flutter_gemma/flutter_gemma.dart, package:gena/features/downloads/data/model_repository.dart, package:gena/features/downloads/data/models/model_info.dart, package:gena/features/downloads/domain/model_info.dart, GemmaChatSession, _modelSpecNameFromSource, ModelRepositoryActions, ActiveModelInstall (+32 more)

### Community 3 - "Community 3"
Cohesion: 0.05
Nodes (39): package:flutter_animate/flutter_animate.dart, package:flutter_dotenv/flutter_dotenv.dart, package:flutter_gemma/core/api/flutter_gemma.dart, package:flutter_gemma/core/domain/web_storage_mode.dart, package:gena/core/router.dart, package:gena/core/theme/app_theme.dart, package:gena/features/chat/presentation/chat_view.dart, package:gena/features/chat/presentation/widgets/chat_app_bar.dart (+31 more)

### Community 4 - "Community 4"
Cohesion: 0.06
Nodes (35): dart:async, ../features/setting/presentation/setting_page.dart, package:gena/features/chat/data/providers/chat_provider.dart, package:gena/features/chat/presentation/chat_page.dart, package:gena/features/chat/presentation/widgets/chat_history_list.dart, package:gena/features/chat/presentation/widgets/chat_model_selection_sheet.dart, package:gena/features/downloads/presentation/download_page.dart, package:gena/features/setting/presentation/model_setting_page.dart (+27 more)

### Community 5 - "Community 5"
Cohesion: 0.07
Nodes (31): dart:io, package:file_picker/file_picker.dart, package:flutter/services.dart, package:gena/core/toast/app_toast.dart, package:path_provider/path_provider.dart, copyToClipboard, build, ChatInputController (+23 more)

### Community 6 - "Community 6"
Cohesion: 0.07
Nodes (28): package:flutter_spinkit/flutter_spinkit.dart, package:gena/features/chat/data/chat_provider.dart, package:gena/features/chat/presentation/widgets/chat_bubble.dart, package:gena/features/chat/presentation/widgets/chat_history_tile.dart, package:lucide_icons_flutter/lucide_icons.dart, _autoScrollToEndIfNeeded, build, Center (+20 more)

### Community 7 - "Community 7"
Cohesion: 0.07
Nodes (27): package:gena/features/chat/data/models/chat_entity.dart, package:gena/features/chat/domain/entities/chat_entity.dart, package:gena/features/chat/domain/entities/message_entity.dart, package:gena/features/setting/data/chat_model_settings_provider.dart, Chats, Constant, GenaDatabase, Messages (+19 more)

### Community 8 - "Community 8"
Cohesion: 0.11
Nodes (19): RegisterPlugins(), FlutterWindow(), OnCreate(), Create(), Destroy(), EnableFullDpiSupportIfAvailable(), GetClientArea(), GetThisFromHandle() (+11 more)

### Community 9 - "Community 9"
Cohesion: 0.08
Nodes (22): package:gena/core/prompt.dart, package:gena/features/setting/data/chat_model_settings.dart, package:shared_preferences/shared_preferences.dart, ChatModelSettings, copyWith, _Keys, build, ChatModelSettingsNotifier (+14 more)

### Community 10 - "Community 10"
Cohesion: 0.09
Nodes (22): package:flutter_highlight/flutter_highlight.dart, package:flutter_highlight/themes/a11y-dark.dart, package:flutter_highlight/themes/a11y-light.dart, package:flutter_highlight/themes/dark.dart, package:flutter_highlight/themes/github.dart, package:gena/core/extension.dart, package:gena/core/utils.dart, Align (+14 more)

### Community 11 - "Community 11"
Cohesion: 0.09
Nodes (22): package:gena/features/chat/presentation/widgets/model_settings_number_field.dart, package:gena/features/chat/presentation/widgets/model_settings_slider_tile.dart, animatedItem, build, Column, dispose, Divider, _font14TextTheme (+14 more)

### Community 12 - "Community 12"
Cohesion: 0.1
Nodes (21): Author, Build APK, Chat, CI/CD, code:bash (flutter pub get), code:bash (flutter build apk --release), Database, Features (+13 more)

### Community 13 - "Community 13"
Cohesion: 0.11
Nodes (19): _, Chat, ChatsCompanion, copyWith, copyWithCompanion, f, Function, map (+11 more)

### Community 14 - "Community 14"
Cohesion: 0.11
Nodes (18): package:gena/features/downloads/presentation/providers/download_notifier.dart, package:gena/features/downloads/presentation/widgets/active_model_install_overlay.dart, package:gena/features/downloads/presentation/widgets/add_model_sheet.dart, package:gena/features/downloads/presentation/widgets/download_models_list.dart, _AddModelSheet, _AddModelSheetState, build, Center (+10 more)

### Community 15 - "Community 15"
Cohesion: 0.13
Nodes (8): package:freezed_annotation/freezed_annotation.dart, ChatEntity, MessageEntity, ChatEntity, MessageEntity, ChatMessage, ModelInfo, ModelInfo

### Community 16 - "Community 16"
Cohesion: 0.14
Nodes (4): fl_register_plugins(), main(), my_application_activate(), my_application_new()

### Community 17 - "Community 17"
Cohesion: 0.18
Nodes (10): build, ChatContextWindowNotifier, ChatContextWindowState, ChatDraftResponseNotifier, ChatDraftThinkingNotifier, ChatGeneratingNotifier, clear, setDraft (+2 more)

### Community 18 - "Community 18"
Cohesion: 0.29
Nodes (8): _, _ChatEntity, class, identical, orElse, StateError, _then, toString

### Community 19 - "Community 19"
Cohesion: 0.29
Nodes (8): _, class, identical, _MessageEntity, orElse, StateError, _then, toString

### Community 20 - "Community 20"
Cohesion: 0.29
Nodes (8): _, class, identical, _ModelInfo, orElse, StateError, _then, toString

### Community 21 - "Community 21"
Cohesion: 0.29
Nodes (8): _, _ChatMessage, class, identical, orElse, StateError, _then, toString

### Community 22 - "Community 22"
Cohesion: 0.29
Nodes (8): _, _ChatEntity, class, identical, orElse, StateError, _then, toString

### Community 23 - "Community 23"
Cohesion: 0.29
Nodes (8): _, class, identical, _MessageEntity, orElse, StateError, _then, toString

### Community 24 - "Community 24"
Cohesion: 0.29
Nodes (8): _, class, identical, _ModelInfo, orElse, StateError, _then, toString

### Community 26 - "Community 26"
Cohesion: 0.33
Nodes (3): RegisterGeneratedPlugins(), NSWindow, MainFlutterWindow

### Community 27 - "Community 27"
Cohesion: 0.47
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

## Knowledge Gaps
- **433 isolated node(s):** `PodsDummy_flutter_gemma`, `PodsDummy_Pods_Runner`, `PodsDummy_shared_preferences_foundation`, `PodsDummy_Pods_RunnerTests`, `PodsDummy_path_provider_foundation` (+428 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **15 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter_riverpod/flutter_riverpod.dart` connect `Community 0` to `Community 1`, `Community 2`, `Community 3`, `Community 4`, `Community 5`, `Community 6`, `Community 7`, `Community 9`, `Community 10`, `Community 11`, `Community 14`, `Community 17`?**
  _High betweenness centrality (0.184) - this node is a cross-community bridge._
- **Why does `package:flutter/material.dart` connect `Community 1` to `Community 2`, `Community 3`, `Community 4`, `Community 5`, `Community 6`, `Community 7`, `Community 9`, `Community 10`, `Community 11`, `Community 14`?**
  _High betweenness centrality (0.124) - this node is a cross-community bridge._
- **Why does `package:flutter_gemma/flutter_gemma.dart` connect `Community 2` to `Community 0`, `Community 4`, `Community 5`, `Community 6`, `Community 7`, `Community 9`, `Community 11`, `Community 14`?**
  _High betweenness centrality (0.037) - this node is a cross-community bridge._
- **What connects `PodsDummy_flutter_gemma`, `PodsDummy_Pods_Runner`, `PodsDummy_shared_preferences_foundation` to the rest of the system?**
  _433 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.04 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._