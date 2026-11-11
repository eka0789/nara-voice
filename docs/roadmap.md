# Roadmap (post-v1)

## v1.1 — Firebase activation (already wired, pending provisioning)

The code is ready; these steps require **your** Firebase console:

1. Create a Firebase project → add Android app `id.nara.voice`.
2. Download `google-services.json` → place at `android/app/google-services.json`.
3. Rebuild — the Gradle plugin auto-activates (conditional apply), anonymous
   sign-in is enabled client-side, and Settings shows "Cloud sync: active".
4. Enable **Anonymous** auth in Console → Authentication.
5. Optional hardening (recommended before store release):
   - **App Check** with Play Integrity: console setup + `FirebaseAppCheck`
     initialization code (see below sketch).
   - **FCM** for cross-device triggers: add `firebase_messaging`, request
     POST_NOTIFICATIONS (already granted surface), wire handlers.

App Check sketch (add to `main.dart` after `initializeApp`):

```dart
// import 'package:firebase_app_check/firebase_app_check.dart';
// await FirebaseAppCheck.instance.activate(
//   androidProvider: AndroidProvider.playIntegrity,
// );
```

## v1.2 — Wake word ("Hey NARA")

- Evaluate **Picovoice Porcupine** (free tier, on-device, custom keyword needs
  console access key) vs **openWakeWord** (fully open, heavier runtime).
- Design constraint: background mic on modern Android requires a
  `microphone` foreground-service type with the user-visible notification;
  battery + privacy trade-off is surfaced in Settings before enabling.

## v1.3 — Assistant role (Phase 8)

- `VoiceInteractionService` + `VOICE_INTERACTION` role request → "Hey Google,
  open NARA" / long-press-home handoff. Requires Play policy review only, no
  new permissions.

## v1.4 — Richer automation

- Screen-flow macros: record → inspect → replay via accessibility actions.
- Notification quick-reply templates (compose through listener + accessibility).
- More registry entries (Drive search, Photos albums, file-manager "find recent
  PDF" via SAF picker — no storage permission needed).

## v2 — Store release

1. Generate an upload keystore:
   `keytool -genkey -v -keystore ~/nara-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias nara`
2. Replace the debug signing config in `android/app/build.gradle.kts` (see the
   TODO comment there) — never commit the keystore or passwords.
3. Play Console: privacy policy (accessibility + notification-listener
   declarations required), data-safety form (see threat model), listing assets.
4. `flutter build appbundle` for AAB distribution.

## Deferred by design (with reasons)

| Item | Reason |
|---|---|
| Auto-send messages/emails | No verifiable delivery API on consumer Android; honesty rule |
| MediaProjection screen understanding | Pixels never needed; accessibility text suffices and is privacy-safer |
| FCM/App Check in v1 | Cannot be provisioned from code — needs console access |
| Multi-account cloud sync | Single anonymous identity is enough for v1 history sync |
