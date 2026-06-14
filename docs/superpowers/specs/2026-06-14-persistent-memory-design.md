# Personas + Persistent Memory — Design

## Decisions (from product owner)

- **Persona = the existing Workspace.** No new "persona" entity. A workspace
  already carries the name + system instruction + tool/RAG toggles that define a
  persona. We extend the workspace with persistent memory (and a light persona
  polish), rather than adding a parallel concept.
- **Memory is tool-based.** The model explicitly stores durable facts via a
  `remember` tool and can drop them via `forget`. Stored facts are auto-injected
  into the system instruction each turn (so a separate `recall` is unnecessary).
  No auto-extraction/summarization in v1.

## Goal

Let the assistant remember durable facts about the user/project across chats
within a workspace, controllably, fully on-device.

## Scope (MVP)

Included: per-workspace memory store; `remember`/`forget` tools; auto-inject
memories into the system instruction; a memory list in workspace config
(view/delete); a per-workspace `memoryEnabled` toggle. Excluded: auto-extraction,
cross-workspace/global memory, vector recall (facts are short; injected verbatim),
embeddings.

## Persistence (Drift, additive)

- New table `WorkspaceMemories(id autoInc, workspace INT FK→Workspaces, content
  TEXT, createdAt)` (TableMixin gives id+createdAt; add `workspace` + `content`).
- Add `memoryEnabled BOOL default true` to `Workspaces`.
- Bump `schemaVersion` 15→16; add ONLY a new `if (from < 16)` block (createTable
  workspaceMemories + addColumn workspaces.memoryEnabled). Never edit existing
  blocks. Run build_runner.
- Bound memory size: cap stored memories per workspace (e.g. 50) and total
  injected chars (e.g. ~2000) — oldest trimmed from injection, never silently
  drop on write without surfacing.

## Architecture

`lib/features/workspace/data/`:
- `workspace_memory_repository.dart` — CRUD over the table (add, list by
  workspace, delete, watch); dedupe near-identical content on add.

Chat wiring (`lib/features/chat/...`):
- **Tools** (`chat_tools.dart` + `genkit_chat_service`): when the active
  workspace has `memoryEnabled` && `supportsFunctionCalls`, register:
  - `remember` — `{content: string}` → stores a fact for the active workspace.
    Local write, low-risk → NO approval (like RAG/web, unlike native/MCP).
    Returns the stored fact + count.
  - `forget` — `{content|id: ...}` → removes a matching memory. Returns status.
  Route these in `executeChatToolByName` to the memory repository via a handler
  injected through `ChatRuntimeDependencies` (mirror the rag/native handler
  pattern). Keep them out of the approval path (local data).
- **Injection**: in `generateAssistantResponseWithGenkit` / the system-prompt
  build, when `memoryEnabled`, load the workspace's memories and append a
  "Remembered facts about the user:" block to the system instruction (bounded).
  Reuse `buildSystemInstruction` by composing the memory block into the base
  prompt before the date context.

UI (`lib/features/workspace/presentation/`):
- In `workspace_config_form.dart`: a `memoryEnabled` toggle (alongside RAG/native
  toggles) + a "Remembered facts" section listing memories with delete buttons
  (and a manual "add" field is optional). Gate behind nothing special (local).

## Capability

Memory is local-only → available on all platforms. No new `AppCapabilities`
flag strictly needed; gate purely on the workspace `memoryEnabled`.

## Data flow

1. Model learns a durable fact → calls `remember{content}` → stored for the
   workspace (no approval).
2. Next turns: memories auto-injected into the system instruction, so the model
   "knows" them without recalling.
3. User reviews/deletes facts in workspace config; model can `forget`.

## Error handling

- Memory cap reached on `remember` → store + trim oldest, or return a clear
  "memory full" status (don't silently drop). 
- Injection bounded by char budget; never blow the context window (counts toward
  the existing context-window planning via the system-instruction token estimate).

## Testing (analyze + unit only)

- Repo CRUD over `NativeDatabase.memory()` (add/list-by-workspace/delete/dedupe/cap).
- `remember` tool stores to the active workspace; `forget` removes; both scoped
  to the workspace (fake repo/handler).
- System-instruction injection: memories appear in the built instruction when
  enabled, absent when disabled, bounded by the char cap.
- Drift migration: schemaVersion 16; `if (from < 16)` present; existing blocks
  unchanged.

## Sequencing

1. Drift table + workspace flag + migration + repo (+ build_runner).
2. `remember`/`forget` tools + handler wiring + execution routing.
3. System-instruction injection (bounded).
4. Workspace-config UI (toggle + memory list/delete).
5. Tests.
6. Device verification (deferred to user).

## Risks

- Memory bloating the context window — bounded injection + cap.
- Duplicate/contradictory facts — dedupe on add; user can prune in UI; `forget`.
- Privacy: memories are sensitive user data — never log content; store local only.
