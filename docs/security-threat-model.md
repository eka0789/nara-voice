# Security Threat Model

Scope: NARA Voice v1 (`id.nara.voice`), Android 7.0+ (API 24).

## Assets

1. User voice transcripts and conversation context (in-memory only).
2. Screen content extracted via accessibility (never persisted).
3. Cloud AI API key (user-supplied, secure storage).
4. The user's device and apps — the integrity of actions NARA performs.

## Trust boundaries

- **User ↔ NARA**: voice/text commands; confirmation cards gate HIGH-risk actions.
- **NARA ↔ OS intents**: fire-and-forget handoffs; NARA cannot verify in-app effects.
- **NARA ↔ cloud AI (optional)**: HTTPS to a user-configured endpoint; only the
  transcript + recent conversation history are sent. Screen content is never sent.

## Threats & mitigations

| # | Threat | Mitigation |
|---|---|---|
| T1 | NLU mishears and executes a destructive action | Risk policy: HIGH actions frozen behind explicit confirmation; no delete/transfer/purchase tools exist at all in v1 |
| T2 | Hallucinated tool/app claims (AI invents success) | Tool registry is a closed whitelist; unknown tool names are dropped (cloud) or clarified (offline); responses are built from actual `ActionResult`s only |
| T3 | Accessibility misuse (silent surveillance) | Service has zero background behavior; inspection only on explicit request; password fields filtered at native layer; nothing written to disk/logs |
| T4 | Notification data exfiltration | Ring buffer of ≤20 titles in memory; never persisted; only surfaced to the user on request; own app excluded |
| T5 | API key leakage | Key in `flutter_secure_storage` (Android Keystore-backed), never in code, logs, or Firebase; endpoint must be HTTPS |
| T6 | Prompt injection through screen/notification text | Cloud client sends only conversation history by default; screen text reaches the cloud only when the user explicitly asks a screen question; tool whitelist bounds any injected instruction to the same capabilities the user already has |
| T7 | Malicious deep link (`file://`, `javascript:`, `content://`) | Scheme blocklist in the native intent handler; `openUrl` restricted to http(s) |
| T8 | Privacy of conversation history | Memory-only, 60-message cap, 10-minute staleness, explicit "clear memory" button; nothing sensitive synced by default (Firebase sync is a no-op unless a project is provisioned, and history sync is best-effort) |
| T9 | Over-privileged installs | No QUERY_ALL_PACKAGES; no contacts/calendar/storage permissions; contact picking via system picker |
| T10 | OTP/password capture via accessibility | `isPassword` nodes skipped entirely (text, bounds, ids); authentication flows are never automated |
| T11 | Unauthorized purchases/transfers | No tool exists for payments; commerce apps can only be *opened* |
| T12 | Repudiation ("NARA did it without asking") | Confirmation cards + workflow history with per-step status, retry-safe |
| T13 | Abusive background execution | No always-on mic, no foreground service, no boot receivers; STT lives only while the app is interactable |

## Residual risks (honest disclosure)

- A user-enabled accessibility service *can* read any visible text on demand —
  this is inherent to the permission; NARA narrows exposure to on-request
  inspection only.
- Speech recognition via the standard recognizer may process audio in Google
  cloud depending on device implementation; on-device recognizer is used where
  available (API 31+).
- The optional cloud AI sees conversation text (not screen content, not
  notifications, not the key) — the user must consciously configure it.
