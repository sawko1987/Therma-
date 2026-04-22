# ADR 002: Unified Logging Stack

## Status

Accepted, 2026-04-21

## Context

SmartCalc Mobile had fragmented `try/catch` handling and no single diagnostic surface for Flutter, Riverpod, navigation, storage, and report export flows. This made support and regression analysis slow, especially on Android where `logcat` and local device files are the primary offline diagnostics channel.

## Decision

We standardize on:

- `talker` as the application logger and in-memory history
- `talker_flutter` for Flutter integration, route observation, and diagnostics UI
- `talker_riverpod_logger` for provider lifecycle logging
- a local persistent `jsonl` ring buffer in `ApplicationDocumentsDirectory/logs/`

The application facade is `AppLogger`. It adds:

- semantic categories: `ui`, `navigation`, `provider`, `repository`, `calculation`, `storage`, `report`
- context redaction for sensitive fields such as `customerPhone`, addresses, and large `payloadJson`
- a common `runLoggedAction` / `AppErrorReporter` pattern for service and UI flows

## Consequences

- In `debug` and `profile`, logs stay verbose enough for flow reconstruction.
- In `release`, the same stack still preserves warnings, errors, and key business events locally.
- Diagnostics are available directly in the app through the settings screen.
- Exported logs remain offline-first and are not sent to third-party services in `v1`.
