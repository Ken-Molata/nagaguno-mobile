# NagaGuno Mobile — Flutter Client

A Flutter mobile client for NagaGuno, an agricultural marketplace connecting farmers, vendors, and buyers in Naga City. Built against the real, existing NagaGuno backend (`nagaguno-real/`, Node/Express + PostgreSQL/Supabase).

**Read `PLATFORM_SETUP.md` first if you're about to build this for real** — this project is currently scoped to **Android only**, for a demo presentation via Android Studio (not an app store submission, and not iOS). It covers the native Android setup specifics (Gradle versions, missing font files). This document is the broader orientation: what's built, what's tested, what's deliberately deferred, and what to check first if something breaks.

## The one thing to know before anything else

**Updated**: this project was built for most of its life with no Flutter SDK or internet access, which is why so much of this document used to talk about "static inspection" and font files that couldn't be fetched. That changed mid-session — a real Flutter 3.41.9 toolchain and real internet access became available — and the backlog it had been waiting on actually got run:

- `flutter pub get` — surfaced and fixed a real version conflict between `google_mlkit_face_detection` and `google_mlkit_image_labeling`/`google_mlkit_commons`.
- The six missing font files (Fraunces + DM Sans) were fetched for real from Google Fonts and committed to `assets/fonts/` — the project's single most-cited blocking gap is closed.
- `flutter analyze` — ran clean after fixing a handful of real errors (an undefined provider reference, a test asserting against a field that had been removed from a model) and migrating every `RadioListTile` off the now-deprecated `groupValue`/`onChanged` API onto `RadioGroup<T>`.
- `flutter test` — all 79 tests pass, after fixing three genuine bugs this first real run caught: a stale `KycIdType` test asserting the old 5-value enum instead of the corrected 10-value one, a test crashing on an uninitialized Flutter binding, and two tests in `blink_state_machine_test.dart` whose own loop logic didn't account for the state machine's real retry-once-per-timeout behavior (the state machine itself was correct — the tests weren't).
- `flutter build apk --debug` — **succeeds**, for the first time ever (`build/app/outputs/flutter-apk/app-debug.apk`), after fixing two real build-level issues (not just Dart) the build itself surfaced: a duplicate-class conflict between an old transitive `firebase-iid` dependency and the newer `firebase_messaging`, and an `ndkVersion` mismatch — see `PLATFORM_SETUP.md` for both fixes. Notably, this only succeeded from a real Terminal-panel shell; every attempt from this agent's own sandboxed command-execution tools failed with a Gradle loopback-socket error specific to that sandbox, not the project.

Anything below still phrased as "unverified" or "can't be checked here" reflects a real external dependency this environment genuinely can't provide (a Google Cloud/Firebase project's actual credentials, a physical Android device, app store accounts) — not a tooling limitation anymore.

## Architecture

- **State management**: Riverpod (`Provider`, `StateProvider`, `StateNotifierProvider`, `FutureProvider`) — no code generation, all hand-written.
- **Networking**: `dio`, with a token-refresh interceptor in `core/networking/api_client.dart` that coalesces concurrent 401s into a single refresh call.
- **Routing**: `go_router`, using `StatefulShellRoute` for the bottom-nav shell. See `app_router.dart`'s header comment and `shared/widgets/app_shell.dart` for why the shell uses one *fixed* 7-branch structure shared across all roles (Home/Marketplace/Agreements/Orders/Production/MyProducts/Profile), with each role's nav bar showing only its relevant subset — not three different per-role branch configurations, which `StatefulShellRoute` can't support without recreating the whole router.
- **Auth**: custom JWT (not Supabase Auth, not Firebase) — 15-minute access tokens held in memory only, longer-lived refresh tokens in `flutter_secure_storage`.
- **Folder layout**: `lib/core/` (networking, storage, theme, validation, utils, connectivity), `lib/features/<feature>/{domain,data,application,presentation}/`, `lib/shared/widgets/` for genuinely cross-feature UI (`VerificationBanner`, `LockedAction`/`LockedButton`, `LinearProgressTracker`).

## Feature completeness

Every feature below is real, wired to the actual backend (not mocked), and has a corresponding screen:

- Auth: register, login, logout, forgot/reset password, email/SMS 2FA on login, email/phone number change, full UW 2.5 account recovery wizard
- KYC: document upload + real on-device liveness detection (ML Kit blink-challenge state machine — see `ml/inference/blink_state_machine.dart`), plus Route A automatic verification via Didit
- Marketplace: browse, search, category filter, sort, flash-sale filter, price range + barangay filter
- **Cart**: add to cart from the marketplace grid or product detail screen, a red badge showing items added, grouped-by-seller cart screen with quantity/remove controls, checkout per seller group — see "Shopping Cart" below for why this is local-only, no backend change needed
- Products: add/edit/hide/delete own listings, spoilage monitoring, flash-sale management, strict on-device + server-side produce-photo validation (see "Content Moderation & Strict Produce-Photo Validation" below)
- Crop plans: add/edit/delete, stage tracking with filtering, same strict produce-photo validation as Products
- Orders: dual-direction (farmer/vendor selling vs. buying), full status lifecycle actions, visual progress tracker, **search by counterparty or product name** ("Orders"/history screen)
- Agreements: dual-direction, creation flow via farmer directory, payment proof upload/review, visual progress tracker
- Farmers directory + saved farmers
- Payment methods management (add/edit/remove receiving methods)
- Reviews & ratings: seller reviews and per-product reviews, surfaced on farmer/vendor/product detail screens
- Chat/messaging between buyer and seller (5-second poll per UW 13.1), with FCM push as a best-effort addition — see "Push Notifications" below
- Appeals: ban/suspension appeal flow, reachable even for a penalized account
- Notifications, with real navigation to the referenced order/agreement/conversation
- Profile viewing and editing (role-adaptive fields)
- Demand forecasting (auto-loading Today/This Week views)
- Admin: KYC review queue, and a Manage Users screen (search by name/email, role/status filters, restrict-or-restore action) — see the code comments for why the rest of admin stays web-only
- Accessibility settings (text scale, high contrast, reduce motion — client-side only, no backend equivalent)
- Offline detection (a banner, not full offline-first caching — see `core/connectivity/`)

**Deliberately not built**: a public vendor directory/profile screen (no such backend endpoint exists — vendor names in the marketplace are plain text, not links, specifically because of this); full admin listing/order/agreement management (web-only by design — Manage Users above is a narrower, additive exception, not a reversal of that decision).

**Real code exists, but needs your own external setup to actually work**: Google Sign-In, Push Notifications (FCM), and server-side content moderation (Google Cloud Vision) — see the dedicated sections below for each. The Dart/backend integration for all three is real and complete; each requires your own external credentials, which can't be fabricated here.

## Testing

`test/` has real unit tests — a fully extracted, dependency-free `BlinkStateMachine`, mocked `AuthController` tests via `mocktail`, validation regex tests, pricing calculation tests, and model-parsing tests. **All 79 pass for real** (`flutter test`) as of this session's tooling access — see "The one thing to know before anything else" above for what that run actually found and fixed.

## CI

`.github/workflows/flutter_ci.yml` runs `dart format --set-exit-if-changed`, `flutter analyze`, and `flutter test` on every push/PR to `main`/`develop`, pinned to Flutter 3.41.9 (the real, actually-installed version reported back during this session — not a guess), plus a separate `build_android` job building a debug APK. Both of this file's former caveats are closed now that real tooling access happened mid-session: the formatting check is a hard gate, not advisory (`dart format .` has actually been run against the whole codebase — 134 of 141 files needed it), and the font files the build job depends on are committed to `assets/fonts/`. The `flutter build apk --debug` command itself is now confirmed to work with this project's real configuration — a real terminal on a real Windows machine ran it successfully (see "What's still genuinely unverified" below and `PLATFORM_SETUP.md`) — but the GitHub Actions pipeline itself (a different OS, a fresh checkout) hasn't actually been triggered from here, so treat the CI job as reasoned from a verified local equivalent, not identically verified.

## A known, real architectural limitation worth knowing about before extending this further

This app mixes `go_router` (the main declarative navigation, including the auth-guarded redirect logic in `app_router.dart`) with plain, imperative `Navigator.of(context).push(MaterialPageRoute(...))` for modal-style sub-screens — currently 7 screens (add/edit product, add/edit crop plan, the liveness camera flow, KYC review detail, and a couple of others). This is a real, recognized category of complexity when mixing the two navigation styles, not a hypothetical: an imperatively-pushed route sits on top of go_router's own internal `Navigator`, and go_router's `refreshListenable`-driven redirect (the mechanism that sends an unauthenticated user to `/login`) operates on its own declarative route stack underneath. It does not automatically pop an imperative route sitting above it.

**Concretely**: if a session is force-expired (an invalid/revoked refresh token, triggering `AuthController.forceLogout()`) while a user happens to be on one of these 7 screens, go_router's internal state correctly updates to "should be on /login," but the visually-displayed screen may remain the stale, imperatively-pushed one until the next navigation action (backing out, or an API call on that screen failing with a 401) surfaces the actual state underneath.

**Why this wasn't fixed rather than just documented**: doing so properly means converting all 7 screens into real nested `go_router` routes (matching the pattern already used for `/marketplace/product/:id`, `/orders/:id`, etc.), which is a legitimate, substantial refactor — not a targeted bug fix. Given session-expiry-while-mid-form is a narrow, non-security-impacting edge case (the user is never shown data they shouldn't see; the worst outcome is a confusing extra navigation step), it's flagged here honestly rather than either silently left for someone to discover confused, or "fixed" with an incomplete patch that doesn't address the actual architectural mismatch.

**A real, if partial, mitigation is in place**: `AuthController.forceLogout()` (called specifically when a refresh attempt fails outright — not on a normal user-initiated logout, which only ever happens from `ProfileScreen`, itself a real `go_router` route) pops any imperatively-pushed screen back to the root via a shared `rootNavigatorKey` (`core/navigation/root_navigator_key.dart`) before the auth-state change triggers the login redirect underneath. This specifically handles the one scenario where the architectural mismatch actually mattered — it does not convert the 7 screens to real routes, and the broader mismatch (if it matters for future features) still needs the fuller refactor described above.

## Google Sign-In — real code, real backend endpoint, but genuine manual setup required

`LoginScreen` has a working "Sign in with Google" flow calling the real, already-existing `POST /auth/google` backend endpoint — including the real business-rule branch where a genuinely new account needs a role (which the backend's own Joi schema doesn't require, but its actual account-creation logic does) prompting a role picker and retrying, rather than failing with a confusing error.

**What still needs your own setup, same discipline as the fonts/Gradle gaps**: a real Google Cloud project with an OAuth 2.0 client ID, `GOOGLE_CLIENT_ID` set in the backend's `.env` (already present as an empty placeholder there), and `google-services.json` for Android (see `PLATFORM_SETUP.md`). None of this can be fabricated here — it requires real credentials from your own Google Cloud Console. **This is entirely optional for a demo** — the "Sign in with Google" button will build and render correctly without it, but tapping it will fail until configured; email/password registration and login work independently of any of this.

## Push Notifications (FCM) — real code, needs your own Firebase project

Chat (UW 13) already works end to end via a 5-second poll (UW 13.1) while a conversation thread is open — push is a parallel, best-effort addition for when the app is backgrounded, never a replacement for the poll. `core/push/push_notification_service.dart` registers the device's FCM token with the real `POST /devices` endpoint on login and unregisters it (`DELETE /devices/:token`) on logout; the backend (`utils/fcmService.js`) sends a push via `firebase-admin` whenever a chat message arrives for an offline recipient, and tapping the notification deep-links straight into that conversation.

**Why Firebase is wired via `FirebaseOptions` + `--dart-define` (`core/configuration/firebase_config.dart`), not the usual `google-services.json` + Gradle-plugin route**: that route needs the real file and plugin present together, or the whole build fails outright — the exact same risk already flagged for Google Sign-In above. This project deliberately avoids it: `main.dart` only calls `Firebase.initializeApp()` when `FirebaseConfig.isConfigured` (all four values non-empty), so the app builds and runs normally with push simply disabled when unconfigured.

**What still needs your own setup**: a real Firebase project, with its four config values passed at build/run time:

```
flutter run --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... --dart-define=FIREBASE_MESSAGING_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=...
```

and `FIREBASE_SERVICE_ACCOUNT_KEY` (the service account JSON, as a string) set in the backend's `.env`. **Entirely optional for a demo** — chat works fully without any of this via the existing poll; only the background push notification itself is affected.

## Content Moderation & Strict Produce-Photo Validation

Two genuinely separate checks, often confused with each other because both run on an uploaded photo — kept distinct deliberately rather than conflated into one:

1. **General content moderation** (adult/violent/racy content, any subject) — `utils/visionService.js`'s `moderateImage()`, used on chat images. Fails open when `GOOGLE_CLOUD_VISION_API_KEY` isn't set in the backend's `.env`.
2. **Strict produce-photo validation** (product and crop-plan listing photos specifically) — a human face or a non-produce subject is now rejected outright, with **no override**. Two independent layers:
   - **On-device, before upload, no setup required**: `lib/core/utils/produce_photo_picker.dart` runs `ml/image_validation/face_presence_detector.dart` (rejects any face) and `produce_classifier.dart` (rejects anything that doesn't look like produce), both via Google ML Kit — the same face-detector package already required for KYC liveness, and an image-labeling model Google documents as MobileNet-derived. This layer needs nothing beyond what KYC liveness already needs, and has no "use anyway" button.
   - **Server-side, when configured**: `utils/visionService.js`'s `checkProducePhoto()` re-runs the same two checks via Google Cloud Vision's `FACE_DETECTION` and `LABEL_DETECTION` (plus SafeSearch), using the same `GOOGLE_CLOUD_VISION_API_KEY` as general moderation above. This is the one layer a non-mobile or modified client can't bypass — it fails open (skipped, not rejected) only when that key isn't configured, in which case the on-device layer is the sole enforcement.

**Why not the literal models originally named (BlazeFace + a bundled MobileNet `.tflite`)**: this was decided before this session had internet access to fetch a real model binary with, and no TensorFlow Lite/TensorFlow.js runtime is wired into this Flutter app (that's a separate integration, e.g. the `tflite_flutter` package, not something the existing ML Kit dependencies provide) — building that out from scratch wasn't revisited after access changed, since ML Kit's on-device face detector and image labeler are real, working, buildable equivalents already proven to run in this exact app for KYC, not a stand-in chosen only for lack of options. The Vision API layer above is a genuinely more capable, cloud-grade version of the same two checks, used as the stronger "second opinion" when its key is present.

**Entirely optional for a demo**: the on-device layer works with zero configuration (same as KYC liveness); only the server-side Vision layer and general chat moderation need `GOOGLE_CLOUD_VISION_API_KEY`.

## Shopping Cart — real code, no external setup needed

There is no cart table or cart endpoint anywhere in the real backend, and that's intentional rather than a gap: `POST /orders` already accepts a multi-item `items` array scoped to a single seller in one call, so the cart (`lib/features/cart/`) only needs to accumulate `{productId, quantity}` pairs client-side before checkout — no backend change was needed. It's local-only, persisted via `shared_preferences` (the same pattern already used for accessibility settings), grouped by seller on the cart screen since one order can only ever be placed for one seller, and cleared on logout so it can't leak between accounts on a shared device. Works fully out of the box; nothing to configure.

## Privacy Policy / Terms of Service — real, working code; not needed for a demo

Both Apple App Store Review and Google Play policy require a privacy policy link for any app collecting personal data — and this one collects government ID photos, biometric liveness data, complete addresses, and phone numbers through the KYC flow specifically. **Not relevant for the current Android-only demo scope**, but built and documented here in case this project moves toward a real release later.

**What's real and built**: `RegisterScreen` shows a real "By registering, you agree to our Terms of Service and Privacy Policy" consent line, and `ProfileScreen` has real, working links for both — all pointing at `EnvConfig.privacyPolicyUrl`/`termsOfServiceUrl`, using `url_launcher` to actually open them. If a URL genuinely hasn't been configured yet (the default for now), tapping the link shows a clear "not yet available" message rather than silently failing or crashing — so it won't disrupt a demo either way.

**What genuinely can't be built here, whenever it does matter**: the actual privacy policy and terms of service documents themselves — real legal documents requiring real legal review of this specific app's actual data practices, not something to fabricate.

## What's still genuinely unverified, now that tooling and font access are no longer the blocker

`flutter analyze`/`flutter test` passing confirms the Dart code is internally consistent — a real `flutter build apk --debug` now **also succeeds** (`build/app/outputs/flutter-apk/app-debug.apk`, built for real in a real terminal after fixing two genuine issues the build itself surfaced — see `PLATFORM_SETUP.md` for the full account: a duplicate-class conflict between an old transitive `firebase-iid` dependency and the newer `firebase_messaging`, fixed with an explicit Gradle exclusion, and an `ndkVersion` bump the build output itself recommended). Notably, the build only succeeded from a real Terminal-panel shell — every attempt from inside this agent's own sandboxed command-execution tools failed with a Gradle loopback-socket error, confirming that restriction was specific to the agent's sandbox, not the project. What's left, in rough order:

1. **`inputImageFromCameraImage` in `ml/inference/liveness_detector.dart` is still unverified against a real device/camera stream** — this is a hardware constraint, not a tooling one (this environment has no physical Android device or emulator camera passthrough to test against). The conversion follows ML Kit's own official Flutter example pattern, and passes static analysis, but a device is the only thing that can actually confirm it against a live YUV420 frame. One specific line (`image.format.raw`) is flagged in its own code comment as the most likely spot to need a small correction if a real device run surfaces one.
2. **The app hasn't actually been run on an emulator or device yet** — a successful build confirms it compiles and packages correctly, not that it behaves correctly once installed and launched. Run it (`flutter run`, or install the built debug APK directly) and exercise the real app, especially KYC liveness per the point above.
3. **iOS is out of scope** for the current Android-only demo — the `ios/Runner/Info.plist` in this project is leftover from earlier, broader-scoped work and can be safely ignored.
4. Once running on a device, **wire `EnvConfig`'s real staging/production API URLs** via `--dart-define` — see `core/configuration/env_config.dart`. The default is a `localhost` fallback for local dev only.

## A pattern worth knowing about if you're extending this codebase

Across this session, the single most common category of real bug was **assuming an existing repository/screen already exposed a backend capability correctly, without re-checking**. Concretely: file names not matching actual API mount points, fraction-vs-percentage confusion on discount fields, a field present in one endpoint's response but missing from a structurally similar one, route-registration order mattering for path matching (both in Express and go_router). The fix each time was the same: read the actual backend route source directly before trusting an assumption about its shape. Recommended to keep doing this when adding new features here, rather than pattern-matching off what looks like a similar existing screen.
