# Background Downloader Migration Design

## Goal

Replace the custom Dio download task running through `smart_background_tasks` with `background_downloader` while preserving the existing model installation API and UI behavior.

## Architecture

`ModelBackgroundDownloadService` remains the single download abstraction used by downloads and chat runtime code. Internally it owns `FileDownloader`, creates stable model download tasks in the `model_downloads` group, stores files under `BaseDirectory.applicationSupport/models`, and translates package task updates into app-specific snapshots.

The service initializes persistent task tracking, reconciles active tasks after restart, configures model download notifications, and exposes cancellation and progress through app-owned types. `DownloadsCubit` no longer imports the downloader plugin or the removed local background-task package.

## Download Behavior

- Use stable task IDs derived from the model key.
- Include the model key in task metadata.
- Pass the Hugging Face bearer token as an authorization header when available.
- Enable pause support, retries, status updates, and progress updates.
- Run large Android downloads in foreground mode with a visible progress notification.
- Return an existing downloaded model file without enqueueing a duplicate task.
- Cancel an existing task for the same model key before starting a replacement.

## Restart Reconciliation

`FileDownloader.start()` restores background updates and reschedules killed tasks. The service queries tracked records and active tasks when initialized, maps them to app snapshots, and keeps the progress stream current after the process restarts.

Model installation remains foreground work. A completed background download is available at the stable application-support path; the user can resume installation by selecting the model again after reopening the app.

## Platform Configuration

- Android keeps notification and foreground data-sync permissions.
- Android replaces the custom `flutter_foreground_task` service with WorkManager's `SystemForegroundService`.
- iOS deployment target becomes 14.0, matching `background_downloader` requirements.
- The direct `smart_background_tasks` dependency is removed.
- `background_downloader` becomes an explicit app dependency.

## Testing

Unit tests cover stable task IDs, task construction, metadata, authorization headers, storage location, and status mapping. Existing widget tests and Flutter analysis verify integration.
