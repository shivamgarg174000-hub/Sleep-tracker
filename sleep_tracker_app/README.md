# Kitty Sleep — Phase 2 complete

Everything from Phase 1 (Auth, Firestore profile, onboarding, Delete Account,
glassmorphism UI, dashboard shell) plus all three deferred features:

## 1. Health Connect / HealthKit
- `lib/core/services/health_service.dart` — real permission flow + data fetch
  via the `health` plugin (Health Connect on Android, HealthKit on iOS).
- `lib/models/health_models.dart` — `DailyHealthSnapshot`, `SleepStageSegment`.
- Home dashboard now shows a real gradient sleep-stage timeline, and glowing
  progress rings for calories/steps sourced from whatever the OS reports —
  with an honest "Connect your wearable" card when no data exists yet.
- **Requires native setup** — see `PLATFORM_SETUP.md`. Without it, permission
  requests correctly return false and the empty state renders; nothing
  crashes, but nothing shows either until that's done.

## 2. Kitty AI — live, via Gemini free tier
- `lib/core/services/ai_service.dart` — calls `gemini-2.5-flash` directly
  from the client (your choice), with the user's profile + today's health
  data injected as a system-instruction context block on every turn.
- `lib/core/services/chat_repository.dart` — full conversation history
  persisted to `users/{uid}/aiConversations`, so chat survives app restarts
  and feeds back in as context on the next message.
- Full chat UI in `kitty_ai_screen.dart` — bubbles, loading state, inline
  error handling (rate limits, timeouts, missing key).
- **Setup**: get a free key at https://aistudio.google.com/apikey, put it in
  `.env` as `GEMINI_API_KEY`. In AI Studio, restrict the key to your app's
  package name / bundle ID before shipping — since it's bundled client-side,
  treat it as semi-public.

## 3. Background audio
- `lib/core/services/audio_service.dart` — `just_audio` playback with a real
  `MediaItem` tag per track, looping by default (correct behavior for sleep
  sounds).
- `JustAudioBackground.init(...)` wired into `main.dart` before `runApp` —
  this is what makes lock-screen media controls appear.
- Soundscapes screen: real play/pause per track, a sleep-timer chip row
  (15/30/45/60 min auto-pause).
- **Two things you still need to supply**: native manifest entries
  (`PLATFORM_SETUP.md`) and actual hosted, licensed audio file URLs — the
  catalog currently has `REPLACE_WITH_YOUR_HOSTED_AUDIO_URL` placeholders,
  since I can't bundle licensed sound content on your behalf. The playback
  engine itself works with any valid direct audio URL the moment those are
  swapped in.

## Updated one-time setup checklist
1. `flutter pub get`
2. `flutterfire configure` (if not already done in Phase 1)
3. Firebase console: enable Google + Anonymous auth, create Firestore DB
   with security rules restricting `users/{uid}` to its owner
4. `cp .env.example .env`, add `GEMINI_API_KEY`
5. Follow `PLATFORM_SETUP.md` for Health Connect/HealthKit AND background
   audio native config (Android manifest entries, iOS capabilities)
6. Replace the placeholder URLs in `audio_providers.dart` with your own
   hosted soundscape files
7. `flutter run`

## What's left, if anything
The four core screens (Sleep dashboard, Soundscapes, Kitty AI, Settings) are
all functionally complete per your original spec. Natural next steps if you
want them: push notifications for sleep-goal reminders, a sleep-history
trends screen (charting past `sleepSessions` docs over time), and haptic
feedback polish on the press-to-start button. Let me know if you'd like any
of those next.
