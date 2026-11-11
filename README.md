# NARA Voice 🎙️

> **Universal AI Voice Assistant for Android** — *"Speak Naturally. NARA Gets It Done."*

NARA listens, understands **Bahasa Indonesia & English**, opens apps, searches
YouTube/Spotify/Maps/web, prepares WhatsApp messages & emails, drafts calendar
events, opens settings, reads notifications, and can even read your screen —
always honestly reporting what succeeded and what did not.

## What works out of the box (production v1)

- ✅ Voice commands (STT streaming + partials, TTS with barge-in)
- ✅ Bilingual NLU (ID/EN) — offline, deterministic, tested; ambiguity → clarifying question, never a guess
- ✅ App discovery (icons, search, launch) without `QUERY_ALL_PACKAGES`
- ✅ Deep links & integrations: WhatsApp, Telegram, Gmail, Maps, YouTube, Spotify, Calendar, Settings
- ✅ Multi-step workflows ("buka YouTube **dan** cari tutorial Flutter") with live progress + retry that never duplicates completed steps
- ✅ Risk engine: HIGH-risk actions (e.g. direct WhatsApp draft to a phone number) require spoken/tapped confirmation
- ✅ Optional screen understanding + notification reader (opt-in, password fields never read, nothing persisted)
- ✅ Transparent permission center
- ✅ Optional cloud AI: bring your own OpenAI-compatible endpoint; key in secure storage; auto-fallback to offline NLU
- ✅ Firebase-ready (add `google-services.json` → sync activates; absent → app runs fully local)

## Quick start

```bash
flutter pub get
flutter analyze      # 0 issues
flutter test         # 53 tests
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

**Android 7.0+ (API 24)**, targetSdk 36. First mic tap requests `RECORD_AUDIO`;
everything else is opt-in from the in-app Permission center.

## Try saying

| Indonesian | English |
|---|---|
| "Buka WhatsApp" | "Open WhatsApp" |
| "Buka YouTube dan cari tutorial Flutter" | "Open YouTube and search Flutter tutorial" |
| "Navigasi ke rumah sakit terdekat" | "Navigate to the nearest hospital" |
| "Kirim pesan WhatsApp ke 0812… isi saya sudah di jalan" | "Send a WhatsApp message to +62… saying I'm on my way" |
| "Siapkan email ke budi@contoh.com subjek rapat isi sampai jumpa besok" | "Compose an email to budi@example.com subject meeting body see you tomorrow" |
| "Jadwalkan rapat besok jam 3" | "Schedule a meeting tomorrow at 3" |
| "Buka pengaturan wifi" | "Open Wi-Fi settings" |
| "Baca notifikasi terbaru" | "Read my recent notifications" |
| "Baca isi layar" | "What's on my screen?" |
| "Buka Bluetooth lalu buka pengaturan wifi" (multi-step) | compound commands via "and/then" |

## Architecture

Feature-first Clean Architecture: `lib/core` (AI, voice, tools, platform
bridges, security) + `lib/features` (UI + controllers). Heavy lifting lives in
native Kotlin under `android/app/src/main/kotlin/id/nara/voice/` across seven
focused engines (discovery, intents, voice, accessibility, notifications,
permissions, device) exposed through seven typed channels.

Deep dive: [docs/architecture.md](docs/architecture.md) ·
[Feasibility & permission matrix](docs/feasibility-matrix.md) ·
[Threat model](docs/security-threat-model.md) ·
[Testing](docs/testing.md) ·
[Roadmap](docs/roadmap.md)

## Safety commitments

- Never reads password fields, never bypasses authentication or CAPTCHA
- Never sends messages/emails on your behalf — it prepares, you press send
- Never claims success it cannot verify (handoff ≠ delivery)
- No always-on microphone, no background monitoring, no data harvesting
- Minimal permissions: no contacts, no calendar, no storage, no QUERY_ALL_PACKAGES

## Enabling Firebase cloud sync (optional)

1. Firebase Console → add Android app `id.nara.voice`
2. Drop `google-services.json` into `android/app/`
3. Rebuild — done. Without this file the app builds and runs 100% local.

## Enabling cloud AI (optional)

Settings → Cloud AI → paste your OpenAI-compatible endpoint + API key
(HTTPS only). The key stays in the device's secure storage. If the endpoint
fails or is unreachable, NARA silently uses its offline brain.

---
Built with Flutter 3.41 · Kotlin 2.4 · Material 3. License: private project — all rights reserved unless stated otherwise.
