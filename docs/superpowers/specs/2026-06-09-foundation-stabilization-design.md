# Foundation Stabilization Design

## Goal

Stabilize Gena's persistence, secret handling, native-tool authorization, workspace service boundaries, and automated test foundation before adding `llama_dart`, Whisper, or new RAG backends.

## Scope

This milestone includes:

- Persist HydratedBloc state in application-support storage instead of temporary storage.
- Stop bundling `.env` as a Flutter asset.
- Introduce a secret-store abstraction backed by `flutter_secure_storage`.
- Move remote-server and model API tokens out of SharedPreferences and Drift plaintext fields.
- Remove sensitive payload, webpage, and token-adjacent logging.
- Replace prefix-based native-tool approval with explicit risk classification.
- Consolidate duplicate workspace action/service implementations.
- Add focused unit and Cubit tests using `bloc_test` and `mocktail`.

This milestone does not include:

- `llama_dart` or GGUF model support.
- Whisper or voice conversations.
- RAG backend replacement.
- UI redesign.
- Database encryption or biometric app locking.

## Architecture

### Application Bootstrap

Create a bootstrap function responsible for initializing persistent storage, dependency injection, secrets, and FlutterGemma before `runApp`.

HydratedBloc uses `getApplicationSupportDirectory()` so selected model, workspace, theme, and settings survive operating-system temporary-directory cleanup.

Bootstrap failures are reported through a small boot-failure application instead of crashing on a forced-null Hugging Face token.

### Secret Storage

Introduce:

```dart
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}
```

`FlutterSecureSecretStore` implements the interface using `flutter_secure_storage`.

Remote servers and model records store a stable secret reference such as:

```text
remote-server:<server-id>
model-api-token:<model-id>
hugging-face-token
```

The actual token is stored only in the secure store. Existing plaintext tokens are migrated lazily when records are loaded or saved, then removed from plaintext persistence.

The Hugging Face token may still be supplied from a development `.env` file, but `.env` is not packaged as an application asset. If absent, FlutterGemma initializes without a token when supported, and authenticated downloads display a clear configuration error.

### Logging

Sensitive values must never be logged:

- Download task payloads.
- API tokens.
- Full remote-server records.
- Raw fetched webpage HTML.
- Full contact payloads.

Web-search logs contain only query, URL host, status, and result counts.

### Native Tool Authorization

Replace `_requiresApproval` prefix matching with explicit tool policy:

```dart
enum NativeToolRisk {
  safeRead,
  sensitiveRead,
  externalAction,
  destructive,
}
```

Policy:

- `get_current_day`, `get_device_info`: no approval.
- RAG and web search: no native approval.
- Reading/searching contacts: approval required because it exposes sensitive data.
- Opening URLs/apps: approval required because it leaves the app.
- Phone calls, SMS, email, contact creation, and flashlight mutation: approval required.
- Unknown native tools: approval required and execution remains rejected by the bridge.

The approval dialog continues to show tool name and arguments.

### Workspace Service Consolidation

Keep the implementations registered by the active GetIt setup and imported by current presentation code.

Remove or redirect duplicate legacy workspace action classes so each concept has one canonical implementation:

- `WorkspaceRagActions`
- `WorkspaceConfigActions`
- Workspace presentation dependency registration

Compatibility export files may remain temporarily, but they only export canonical implementations and contain no duplicate classes.

### Tests

Add `bloc_test` and `mocktail`.

Initial tests cover:

- Native tool risk classification and approval decisions.
- Secure remote-server serialization excluding tokens.
- Secret-store migration from legacy remote-server token data.
- Hydrated storage directory selection through an injectable bootstrap dependency.
- Workspace action registration resolves one canonical implementation.
- Logging helpers redact known sensitive keys.

Existing smoke tests remain. No integration test is required for this milestone because secure-storage platform behavior requires device-level setup; the repository abstraction is unit tested instead.

## Data Migration

The existing Drift `apiToken` column remains during this milestone for schema compatibility, but application code stops treating it as the source of truth.

When a model with a plaintext `apiToken` is read:

1. Write the token to secure storage.
2. Clear the Drift `apiToken` value.
3. Use the secure-store value for future requests.

When a legacy remote-server JSON entry containing `token` is read:

1. Write the token to secure storage.
2. Persist the remote-server list without token values.
3. Resolve the token from secure storage when connecting.

This avoids a destructive schema migration before the engine abstraction changes the model schema.

## Error Handling

- Secure-store failures produce typed errors and never fall back to plaintext token persistence.
- Missing optional Hugging Face credentials do not prevent app startup.
- Authenticated model downloads fail with a user-facing credential message.
- Failed legacy-token migration leaves the original token intact until secure persistence succeeds.
- Bootstrap failures render a retryable failure screen and are logged without secrets.

## Definition of Done

- `flutter analyze` passes.
- `flutter test` passes.
- HydratedBloc no longer uses a temporary directory.
- `.env` is not bundled as an asset.
- New or updated remote/model tokens are stored only in secure storage.
- Existing plaintext tokens migrate safely.
- No raw download payloads or webpage HTML are logged.
- Every sensitive or external native tool requires explicit approval.
- Duplicate workspace action implementations are removed or reduced to compatibility exports.
- Focused tests protect the new behavior.
