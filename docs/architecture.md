# NARA Voice — Architecture

> Universal AI Voice Assistant for Android. **"Speak Naturally. NARA Gets It Done."**

## 1. Overview

NARA Voice is a Flutter application with a substantial native Kotlin layer, implementing
voice-driven device automation: it listens, understands Indonesian and English commands,
plans actions, asks for confirmation when risky, executes through public Android
mechanisms, and reports what *actually* happened — never an assumed success.

```
┌────────────────────────── Flutter (Dart) ──────────────────────────┐
│  features/ (UI + controllers)     core/ (pure logic + bridges)     │
│  voice_assistant  automation      ai/ (NLU, orchestrator, cloud)   │
│  app_discovery    permissions     voice/ (STT/TTS facade)          │
│  settings         screen_…        tools/ (tool schema + registry)  │
└──────────────────────────────┬─────────────────────────────────────┘
                               │ MethodChannel / EventChannel
┌──────────────────────────────┴─────────────────────────────────────┐
│  Native Kotlin (id.nara.voice)                                     │
│  apps/     App Discovery Engine (PackageManager, package queries)  │
│  intents/  App Integration Engine (public Intents, deep links)     │
│  voice/    SpeechRecognizer (streaming) + TextToSpeech             │
│  accessibility/  optional screen understanding + UI actions        │
│  notifications/  optional notification ring buffer                 │
│  permissions/    minimal runtime-permission surface                │
│  device/   read-only device facts                                  │
└────────────────────────────────────────────────────────────────────┘
```

## 2. Layering rules

- `core/` never imports `features/`. Feature controllers compose core services.
- Platform code is reachable **only** through `core/platform/*` wrappers; business
  logic never touches `MethodChannel` directly.
- Tools are the only way plans touch the device: a `NaraTool` validates its input
  against a declared schema, executes through a platform bridge, and returns an
  honest `ActionResult`. There is no shell access, no reflection, no arbitrary code
  execution path.
- UI strings for the user are localized in `ResponseLocalizer` (voice) and
  `AppLocalizations` (widgets); logic emits stable `ResponseKey`s instead of text.

## 3. AI architecture (hybrid, cloud-optional)

1. **Offline NLU** (`core/ai/nlu/`) — deterministic, testable: normalization +
   filler stripping (ID/EN), ordered intent matchers, fuzzy app-name matching over
   the live catalog, slot filling with expiry, compound-command splitting
   ("buka YouTube **dan** cari X" → 2 steps) with app-context routing.
2. **Cloud adapter** (`core/ai/cloud/`) — OpenAI-compatible function calling with
   the *same* tool registry the offline path uses. Configured by the user in
   Settings (endpoint + key in `flutter_secure_storage`). Any failure (timeout,
   HTTP error, malformed response) silently falls back to offline NLU.
3. **Orchestrator** (`core/ai/orchestrator.dart`) — plans → risk-gates → executes
   sequentially → verifies → builds the localized response from actual step results.
4. **Risk policy** (`core/security/risk_policy.dart`) — LOW/MEDIUM/HIGH per spec.
   HIGH steps freeze the plan behind a confirmation card; the user's yes/no may be
   spoken or tapped.

### Deviations from the original spec (documented decisions)

| Spec item | Decision |
|---|---|
| Freezed for models | Hand-written immutable classes. The model surface is small value objects; skipping codegen removes a whole build-failure class while keeping identical semantics (immutability, const constructors). |
| Auto-send messages/emails | Never implemented. Consumer Android offers no verifiable delivery API; NARA *prepares* drafts and the user presses send. This satisfies the honesty rule (§1: never pretend an unsupported operation succeeded) and the DoD ("prepare messages and emails"). |
| MediaProjection screen understanding | AccessibilityNodeInfo (text-structured) only. Screen pixels never leave the device. |
| Wake word (Phase 8) | Deferred — see `roadmap.md`. |
| FCM / App Check | Deferred — require Firebase console provisioning; documented in `roadmap.md`. |

## 4. Android version compatibility

| Feature | min API | Notes |
|---|---|---|
| App discovery & launch | 24 | Package visibility via `<queries>` (no QUERY_ALL_PACKAGES) |
| STT (standard) | 24 | Google-backed recognizer |
| STT (on-device) | 31 | `createOnDeviceSpeechRecognizer` |
| TTS | 24 | Engine-dependent language availability |
| Deep links / share sheet | 24 | Public intents only |
| Accessibility actions | 24 | `dispatchGesture` fallbacks |
| Notification listener | 24 | Opt-in, in-memory only |
| POST_NOTIFICATIONS | 33 | Runtime dialog on 13+, auto-granted below |

minSdk 24 · targetSdk/compileSdk 36 · Java/Kotlin target 17.

## 5. Data flow — one command end to end

1. `SpeechService` streams partials → UI bubble; final transcript → controller.
2. Controller: transcript → `Orchestrator.plan()` (cloud first if configured, else NLU).
3. `NeedClarify` → spoken question + slot stored in `ConversationMemory` (TTL 3 min).
4. `PlanReady` → HIGH risk? confirmation card → `execute()` else straight to `execute()`.
5. `execute()` runs each step through `ToolRegistry` (validate → timeout → verify),
   mutating step statuses that drive the progress UI live.
6. `ResponseLocalizer.outcome()` turns real step results into ID/EN sentences → TTS.
7. Multi-step plans are persisted as `WorkflowRun`s (retry-safe: completed steps
   never re-run).
