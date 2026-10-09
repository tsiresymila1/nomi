# Image Generation Chat Flow Design

## Goal

Make image generation behave like a normal chat turn: the prompt leaves the
composer immediately, appears as a user message, and generation progress is
shown as an assistant item in the conversation.

## Root cause

`ChatInput._generateImage` clears the text controller only after generation
succeeds. `ImageGenerationActions.generateAndPersist` also waits for the image
runtime before inserting both messages. Meanwhile,
`ImageGenerationStatusPanel` is rendered above the composer, so active progress
is visually detached from the conversation.

## Design

- Validate the selected chat and persist the normalized user prompt before
  starting the image runtime.
- Clear the composer as soon as the generation request is accepted.
- Keep the active prompt in `ImageGenerationState` so retry can reuse it without
  inserting a duplicate user message.
- Render loading, generation progress, cancellation, and failure as the final
  transient assistant item in `ChatView`.
- Keep model readiness, installation, verification, and removal controls in the
  composer because they configure the image runtime rather than represent a
  chat response.
- On success, remove the transient item naturally when the persisted image
  message arrives.
- On failure or cancellation, retain the user prompt and show a timeline card.
  Retry reuses the existing user turn and persists only the eventual assistant
  image.

## Persistence and recovery

The user prompt is durable before expensive generation begins. Transient
progress is intentionally not stored in Drift, preventing stale loading rows
after an app process restart. A failed or cancelled generation therefore leaves
a useful user turn but no broken assistant image record.

## Testing

- Data tests prove the prompt exists before the image future completes and
  remains after failure or cancellation.
- Cubit tests prove the active prompt is retained and retry does not request a
  second user-message insertion.
- Widget tests prove active generation appears in the chat timeline and that
  runtime preparation remains in the composer.
- Existing image generation, chat, analysis, and full Flutter tests remain
  green.
