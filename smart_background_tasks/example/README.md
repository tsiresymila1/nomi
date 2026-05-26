# smart_background_tasks example

This example demonstrates:

- Start one `dio` download task
- Start three tasks concurrently
- Pause task
- Resume task
- Cancel task
- Cancel all tasks
- Real-time progress via `LinearProgressIndicator`
- Notification mode switch:
  - `grouped`: single foreground summary notification
  - `perTask`: foreground summary + one local notification per task

It also displays default model source URLs based on flutter_gemma model hubs:

- Gemma 4 E2B
- Qwen3 0.6B
- DeepSeek R1

## Download task details

- Task factory: `createDemoModelTask`
- Task implementation: `DioDownloadTask`
- Progress source: `dio.download` with `onReceiveProgress`
- Download URL payload key: `downloadUrl`
- Destination filename payload key: `fileName`

The current sample uses Cloudflare speed test endpoint URLs to make progress visible:

- `https://speed.cloudflare.com/__down?bytes=4000000`
- `https://speed.cloudflare.com/__down?bytes=5000000`
- `https://speed.cloudflare.com/__down?bytes=6000000`
