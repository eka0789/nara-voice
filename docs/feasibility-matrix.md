# Feasibility & Capability Matrix

## 1. Android integration feasibility

| Capability | Mechanism | Feasible without special permission? | Status |
|---|---|---|---|
| Discover installed (launchable) apps | `PackageManager.queryIntentActivities(MAIN/LAUNCHER)` + `<queries>` | ✅ | ✅ Implemented |
| App icons | `getApplicationIcon` → PNG bytes | ✅ | ✅ Implemented |
| Launch app | `getLaunchIntentForPackage` | ✅ | ✅ Implemented |
| Open website | `ACTION_VIEW https:` | ✅ | ✅ Implemented |
| WhatsApp message prep | `wa.me/<phone>?text=` / `ACTION_SEND` pkg-restricted | ✅ | ✅ Implemented (user sends) |
| SMS prep | share sheet to default SMS app | ✅ | ✅ Implemented (user sends) |
| Email prep | `ACTION_SENDTO mailto:` | ✅ | ✅ Implemented (user sends) |
| Maps search / navigation | `geo:` / `google.navigation:` | ✅ | ✅ Implemented |
| YouTube search | app URI → web fallback | ✅ | ✅ Implemented |
| Spotify open/search | `spotify:` URI → web fallback | ✅ | ✅ Implemented |
| Calendar event draft | `ACTION_INSERT` | ✅ (no calendar permission needed for the intent draft) | ✅ Implemented |
| Settings screens | `Settings.ACTION_*` whitelist | ✅ | ✅ Implemented |
| Screen reading | AccessibilityService (opt-in) | ⚠️ user must enable in system settings | ✅ Implemented (optional) |
| Tap / type / scroll in other apps | Accessibility actions + gestures (opt-in) | ⚠️ opt-in | ✅ Implemented (optional) |
| Recent notifications | NotificationListenerService (opt-in) | ⚠️ opt-in | ✅ Implemented (optional) |
| Foreground app detection | AccessibilityService window events | ⚠️ opt-in | ✅ Implemented (optional) |
| Speech recognition | `SpeechRecognizer` (RECORD_AUDIO) | ⚠️ runtime mic permission | ✅ Implemented |
| TTS | `TextToSpeech` | ✅ | ✅ Implemented |
| Read/parse arbitrary app internals | — | ❌ not possible / policy-forbidden | 🚫 Honest "unsupported" response |
| Toggle protected system settings (e.g. Bluetooth radio) | — | ❌ requires user action | 🚫 Opens the relevant settings screen instead |
| Verify message delivery in third-party apps | — | ❌ no public API | 🚫 NARA reports handoff, never delivery |
| Auto-send messages | — | ❌ deliberately not implemented | 🚫 see architecture.md deviations |
| Wake word always-on | Picovoice Porcupine or similar | ⚠️ needs account/licensing | ⏭ roadmap |

## 2. Per-app capability matrix (integration registry)

| App | Package | Capabilities | Deep links | Verified by |
|---|---|---|---|---|
| WhatsApp | `com.whatsapp` | messaging | `wa.me`, `whatsapp://` | live `resolveActivity` check |
| Telegram | `org.telegram.messenger` | messaging | `tg://` | share-target restricted send |
| Gmail | `com.google.android.gm` | email | `googlegmail://` | mailto resolves to it |
| Google Maps | `com.google.android.apps.maps` | maps, navigation | `geo:`, `google.navigation:` | geo intent resolution |
| YouTube | `com.google.android.youtube` | media, video | `vnd.youtube://` | app URI → web fallback |
| Spotify | `com.spotify.music` | media, music | `spotify:` | app URI → web fallback |
| Chrome | `com.android.chrome` | browser | `http(s)://` | VIEW resolution |
| Google Calendar | `com.google.android.calendar` | productivity, calendar | INSERT | intent draft |
| Instagram / Facebook | `com.instagram.android`, `com.facebook.katana` | social | scheme URIs | launch intent |
| Any other app | discovered live | open/launch | — | launch intent |

Unknown apps are handled gracefully: fuzzy name matching over the live catalog,
and a spoken "app not found / not available" when there is genuinely no match.

## 3. Permission matrix

| Permission | Type | When requested | What it enables | Revocation path |
|---|---|---|---|---|
| `RECORD_AUDIO` | runtime dialog | first mic tap | voice commands | Permission center → system settings |
| `POST_NOTIFICATIONS` | runtime dialog (13+) | first use needing it | NARA status notifications | Permission center |
| Accessibility service | system toggle | user-initiated from Permission center | screen reading + assisted taps | Permission center → Android accessibility settings |
| Notification listener | system toggle | user-initiated | recent-notifications answers | Permission center → listener settings |
| `INTERNET`, `ACCESS_NETWORK_STATE` | install-time | — | web search, cloud AI (optional), Firebase | uninstall |
| — | — | — | contacts/calendar/storage never requested | intent-based pickers used instead |

**Deliberately NOT requested:** `QUERY_ALL_PACKAGES`, `READ_CONTACTS`,
`READ_CALENDAR`, `WRITE_EXTERNAL_STORAGE`, `READ_NOTIFICATIONS` (raw),
`SYSTEM_ALERT_WINDOW`, background-location.
