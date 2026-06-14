import 'workspace_rag_backend.dart';
// Selects the native mobile_rag_engine backend where dart:io is available, and
// the unsupported backend on web.
import 'unsupported_workspace_rag_backend.dart'
    if (dart.library.io) 'mobile_workspace_rag_backend.dart'
    as impl;

/// Returns the workspace RAG backend for the current platform.
WorkspaceRagBackend createWorkspaceRagBackend() =>
    impl.createWorkspaceRagBackend();
