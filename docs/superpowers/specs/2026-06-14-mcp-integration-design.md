# MCP Integration — Design

## Goal

Let users connect gena to remote **MCP (Model Context Protocol) servers** and
expose those servers' tools to the chat model, so the assistant can call
external MCP tools mid-conversation — alongside the existing web/calculator/
RAG/native tools. Matches Off Grid's Pro "MCP server integrations".

## Transport & package

- **`mcp_dart` ^2.2.1** — `Client` + `StreamableHttpClientTransport`
  (`serverUri`, custom headers/auth). Streamable HTTP works on Flutter mobile +
  web. Client API: `listTools()`, `callTool(name, args)`. Dart ^3.0 (compatible).
- Only the **remote (HTTP/SSE) transport** is used — stdio/subprocess is not
  viable on mobile. So an "MCP server" in gena = a Streamable HTTP URL (+ optional
  auth header), exactly like the existing remote-server concept.

## Scope (MVP)

Included: configure/manage remote MCP servers; per-workspace enable; discover
their tools on chat start; register as Genkit tools; route calls via mcp_dart;
require user approval for MCP tool calls (external). Excluded: stdio transport,
MCP resources/prompts/sampling (tools only), OAuth flows (bearer header only),
gena acting as an MCP server.

## Persistence (Drift, additive)

- New table `McpServers(id, name, url, authHeader TEXT nullable, enabled BOOL)`.
  Bump `schemaVersion` 14→15; add ONLY a new `if (from < 15)` migration block
  (create table + add the workspace column below). Never edit existing blocks.
- Add `mcpEnabled BOOL default false` to `Workspaces` (per-workspace gate, like
  `ragEnabled`/`nativeToolsEnabled`).
- Auth header value: store like the existing remote-server token handling
  (follow whatever `remote_servers` does today — secure store if present, else
  the same column approach). Do not log it.

## Architecture

New feature module `lib/features/mcp/`:
- `data/models/mcp_server.dart` — app model.
- `data/services/mcp_client_manager.dart` — provider-neutral boundary:
  `Future<List<McpToolDef>> discoverTools(List<McpServer> enabledServers)` and
  `Future<Map<String,dynamic>> callTool(serverId, toolName, args)`. Caches one
  `Client` per server; connect lazily; dispose on reset. Injectable/fake-able.
- `data/services/mcp_client_factory.dart` — conditional if needed (mcp_dart
  works on web+native, so likely no conditional factory; keep the manager
  behind an interface for testing).
- `data/mcp_repository.dart` — CRUD over the Drift table.
- `presentation/` — manage-servers page + form (mirror `features/remote_servers`).

### Tool bridging
- MCP tool name → namespaced unified tool name `mcp__<serverId>__<toolName>`
  (avoids collisions with built-ins). Map MCP inputSchema → the existing
  `UnifiedChatToolDefinition.parameters` (JSON schema passthrough).
- `genkit_chat_service`/`buildUnifiedChatToolDefinitions`: when the active
  workspace has `mcpEnabled` and `supportsFunctionCalls`, append discovered MCP
  tool defs. `_registerTools` already turns defs into Genkit tools; extend the
  execution closure so `mcp__*` names route to `McpClientManager.callTool`.
- Discovery happens once per generation (or cached with TTL) — keep it resilient:
  a server that fails to connect is skipped with a logged warning, never blocks
  the other tools or the chat.

### Approval (security)
- MCP tools are EXTERNAL actions → **require user approval** before execution,
  reusing the existing native-tool approval flow (`NativeToolActions`/approval
  cubit + the approval sheet showing tool name + args). Add MCP tool calls to
  that approval path (server + tool + args shown). Never auto-execute an MCP
  tool without approval. A denied/cancelled approval returns a tool error.

### Capability
- `AppCapabilities.supportsMcp` — true on all platforms (remote feature; works
  on web too). Gate the manage-servers UI + workspace toggle on it (always true
  for now, but keep the seam).

## Data flow
1. User adds an MCP server (name, URL, optional auth header), enables it.
2. Workspace has `mcpEnabled = true`.
3. On send, `McpClientManager.discoverTools` connects to enabled servers, lists
   tools, returns namespaced defs → appended to the tool set.
4. Model calls `mcp__<server>__<tool>` → approval prompt → on approve,
   `callTool` → result returned to the Genkit tool loop (compacted like other
   tool results).

## Error handling
- Connect/list/call failures: typed error, logged (no auth header), surfaced as
  a tool error to the model; other tools/chat unaffected.
- Web: works (remote). No native permission needed.

## Testing (no device build — analyze + unit tests only)
- Repository CRUD over an in-memory Drift db (NativeDatabase.memory).
- `McpClientManager` with a FAKE mcp client: tool discovery → namespaced
  `mcp__server__tool` defs; `callTool` routes to the right server/tool; a failing
  server is skipped, others still returned.
- Tool-name namespacing + inputSchema→parameters mapping.
- Approval required: an MCP tool call goes through the approval path; denial →
  tool error (fake approval handler).
- Drift migration: schemaVersion 15, additive `if (from < 15)` only.
- Capability: `supportsMcp` true across platforms.

## Sequencing
1. Drift table + workspace flag + migration + repo (+ build_runner).
2. `McpClientManager` boundary + mcp_dart impl + fake + tests.
3. Tool bridge (namespacing, schema map) into `buildUnifiedChatToolDefinitions`
   + execution routing + approval.
4. Manage-servers UI + workspace toggle.
5. Capability + DI wiring.
6. Device verification (real MCP server) — deferred to user.

## Risks
- mcp_dart StreamableHttp behavior/version drift — pin and adapt to the actual
  installed API (verify `Client`/transport/`listTools`/`callTool` signatures).
- Tool-name collisions / overly long names — namespacing handles it; clamp length.
- Latency: discovery on every send adds a round-trip — cache per generation and
  fail fast on unreachable servers.
- Approval fatigue if a model spams MCP tools — `maxTurns` already bounds the loop.
