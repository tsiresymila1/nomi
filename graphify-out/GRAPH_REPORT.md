# Graph Report - gena  (2026-05-16)

## Corpus Check
- 82 files · ~29,901 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 383 nodes · 402 edges · 55 communities (41 shown, 14 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 8 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `2aa6ae0d`
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

## God Nodes (most connected - your core abstractions)
1. `_` - 19 edges
2. `package:flutter/material.dart` - 15 edges
3. `package:flutter_riverpod/flutter_riverpod.dart` - 15 edges
4. `_` - 9 edges
5. `_` - 9 edges
6. `_` - 9 edges
7. `_` - 9 edges
8. `package:flutter_gemma/flutter_gemma.dart` - 7 edges
9. `AppDelegate` - 6 edges
10. `Create()` - 6 edges

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

## Communities (55 total, 14 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.07
Nodes (26): dart:async, package:drift/drift.dart, package:gena/core/database/gena_database.dart, package:gena/core/database/gena_provider.dart, package:gena/features/chat/domain/entities/chat_entity.dart, package:gena/features/chat/domain/entities/message_entity.dart, Chats, GenaDatabase (+18 more)

### Community 1 - "Community 1"
Cohesion: 0.11
Nodes (19): RegisterPlugins(), FlutterWindow(), OnCreate(), Create(), Destroy(), EnableFullDpiSupportIfAvailable(), GetClientArea(), GetThisFromHandle() (+11 more)

### Community 2 - "Community 2"
Cohesion: 0.08
Nodes (24): package:drift_flutter/drift_flutter.dart, package:flutter_dotenv/flutter_dotenv.dart, package:flutter_gemma/core/api/flutter_gemma.dart, package:flutter_gemma/core/domain/web_storage_mode.dart, package:flutter_highlight/flutter_highlight.dart, package:flutter_highlight/themes/dark.dart, package:flutter_highlight/themes/github.dart, package:flutter_riverpod/flutter_riverpod.dart (+16 more)

### Community 3 - "Community 3"
Cohesion: 0.07
Nodes (25): ../features/setting/presentation/setting_page.dart, package:gena/features/chat/presentation/chat_page.dart, package:gena/features/chat/presentation/chat_view.dart, package:gena/features/chat/presentation/widgets/chat_history_list.dart, package:gena/features/chat/presentation/widgets/chat_input.dart, package:gena/features/downloads/presentation/download_page.dart, package:gena/features/setting/presentation/model_setting_page.dart, package:go_router/go_router.dart (+17 more)

### Community 4 - "Community 4"
Cohesion: 0.09
Nodes (19): package:flutter/material.dart, package:flutter_test/flutter_test.dart, package:gena/main.dart, AppTheme, dark, _filledButtonTheme, FilledButtonThemeData, _inputDecorationTheme (+11 more)

### Community 5 - "Community 5"
Cohesion: 0.1
Nodes (19): package:gena/core/logger.dart, package:gena/features/downloads/data/model_repository.dart, package:gena/features/downloads/domain/model_info.dart, ActiveModelInstall, ActiveModelInstallNotifier, clear, DownloadNotifier, _inferFileType (+11 more)

### Community 6 - "Community 6"
Cohesion: 0.11
Nodes (18): package:file_picker/file_picker.dart, package:flutter/services.dart, package:gena/features/downloads/presentation/providers/download_notifier.dart, package:gena/features/downloads/presentation/widgets/download_item.dart, _AddModelSheet, _AddModelSheetState, build, Center (+10 more)

### Community 7 - "Community 7"
Cohesion: 0.12
Nodes (18): _, Chat, ChatsCompanion, copyWith, copyWithCompanion, f, Function, map (+10 more)

### Community 8 - "Community 8"
Cohesion: 0.12
Nodes (14): dart:io, package:gena/features/chat/data/chat_provider.dart, package:lucide_icons_flutter/lucide_icons.dart, build, ChatHistoryList, _ChatHistoryTile, _formatDate, ListTile (+6 more)

### Community 9 - "Community 9"
Cohesion: 0.12
Nodes (15): package:gena/features/setting/data/chat_model_settings_provider.dart, build, Column, dispose, Divider, initState, _loadSettingsIntoForm, _markEdited (+7 more)

### Community 10 - "Community 10"
Cohesion: 0.13
Nodes (13): package:flutter_gemma/flutter_gemma.dart, package:gena/features/chat/presentation/widgets/chat_bubble.dart, _autoScrollToEndIfNeeded, build, Center, ChatBubble, ChatView, _ChatViewState (+5 more)

### Community 11 - "Community 11"
Cohesion: 0.14
Nodes (4): fl_register_plugins(), main(), my_application_activate(), my_application_new()

### Community 12 - "Community 12"
Cohesion: 0.17
Nodes (10): package:gena/features/setting/data/chat_model_settings.dart, package:shared_preferences/shared_preferences.dart, build, ChatModelSettingsNotifier, save, build, _fromRaw, setMode (+2 more)

### Community 13 - "Community 13"
Cohesion: 0.22
Nodes (5): package:freezed_annotation/freezed_annotation.dart, ChatEntity, MessageEntity, ChatMessage, ModelInfo

### Community 14 - "Community 14"
Cohesion: 0.29
Nodes (8): _, _ChatMessage, class, identical, orElse, StateError, _then, toString

### Community 15 - "Community 15"
Cohesion: 0.29
Nodes (8): _, _ChatEntity, class, identical, orElse, StateError, _then, toString

### Community 16 - "Community 16"
Cohesion: 0.29
Nodes (8): _, class, identical, _MessageEntity, orElse, StateError, _then, toString

### Community 17 - "Community 17"
Cohesion: 0.29
Nodes (8): _, class, identical, _ModelInfo, orElse, StateError, _then, toString

### Community 19 - "Community 19"
Cohesion: 0.33
Nodes (3): RegisterGeneratedPlugins(), NSWindow, MainFlutterWindow

### Community 20 - "Community 20"
Cohesion: 0.47
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

## Knowledge Gaps
- **222 isolated node(s):** `PodsDummy_flutter_gemma`, `PodsDummy_Pods_Runner`, `PodsDummy_shared_preferences_foundation`, `PodsDummy_Pods_RunnerTests`, `PodsDummy_path_provider_foundation` (+217 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **14 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter_riverpod/flutter_riverpod.dart` connect `Community 2` to `Community 0`, `Community 3`, `Community 5`, `Community 6`, `Community 8`, `Community 9`, `Community 10`, `Community 12`?**
  _High betweenness centrality (0.108) - this node is a cross-community bridge._
- **Why does `package:flutter/material.dart` connect `Community 4` to `Community 2`, `Community 3`, `Community 5`, `Community 6`, `Community 8`, `Community 9`, `Community 10`, `Community 12`?**
  _High betweenness centrality (0.106) - this node is a cross-community bridge._
- **Why does `package:flutter_gemma/flutter_gemma.dart` connect `Community 10` to `Community 0`, `Community 9`, `Community 5`, `Community 6`?**
  _High betweenness centrality (0.028) - this node is a cross-community bridge._
- **What connects `PodsDummy_flutter_gemma`, `PodsDummy_Pods_Runner`, `PodsDummy_shared_preferences_foundation` to the rest of the system?**
  _222 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.07 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.11 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.08 - nodes in this community are weakly interconnected._