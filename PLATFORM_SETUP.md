# Platform Setup — Read Before Building

## Scope: Android only, for a demo presentation

This project is being built for an Android demo via Android Studio — not
an app store submission, and not iOS. Android Studio is a completely
standard, good choice for this: full Flutter plugin support, a bundled
emulator, and what most Flutter developers use day to day. Everything
below is scoped accordingly. The `ios/Runner/Info.plist` file that
exists in this project is leftover from earlier, broader-scoped work
this session and can be safely ignored — nothing here depends on it,
and it doesn't need to be finished, merged, or even opened for an
Android-only demo.

## Real Gradle/Android values, verified not guessed

This project was originally built with no Flutter SDK access, so the
Android Gradle build files were deliberately left out rather than
guessed at. That gap is closed: a real `flutter create` was run in a
separate environment with Flutter (initially reported as 3.35.5, later
confirmed as the newer 3.41.9 actually installed) and the generated
values were used to write the real files below.

| Setting | Value used |
|---|---|
| Gradle wrapper | 8.12 |
| AGP (Android Gradle Plugin) | 8.9.1 |
| Kotlin Gradle plugin | 2.1.0 |
| compileSdk / targetSdk | 36 |
| minSdk | 24 |
| NDK version | 27.0.12077973 |
| Java compatibility | VERSION_11 |
| `android.useAndroidX` / `android.enableJetifier` | both `true` |

**Worth double-checking once you actually build**: these numbers came
from Flutter 3.35.5's real output; you later confirmed your actual
installed version is 3.41.9 — several releases apart. If Android
Studio / `flutter create` on your machine generates different values
for `settings.gradle`/`build.gradle` (run `flutter create` into a
throwaway folder and compare), trust what your real toolchain
generates over what's committed here.

Files written using these values: `android/settings.gradle`,
`android/build.gradle`, `android/app/build.gradle`,
`android/gradle/wrapper/gradle-wrapper.properties`,
`android/gradle.properties`,
`android/app/src/main/kotlin/com/nagaguno/mobile/MainActivity.kt`.

**One file still deliberately NOT included: `android/local.properties`.**
This records the actual filesystem paths to your Flutter SDK and
Android SDK — genuinely machine-specific. Android Studio (or
`flutter create`) will generate it automatically the first time you
open this project or build it.

## `AndroidManifest.xml` — hand-authored, not `flutter create` output

Contains the permission declarations every real feature in this app
actually needs: camera + photo library access (KYC liveness, photo
uploads across products/crop plans/profile/payment proof), and
internet access for the API. If Android Studio regenerates this file
via `flutter create`, merge this session's `<uses-permission>` entries
into the fresh version rather than overwrite it outright — the
generated version will have additional required attributes (icon
references, theme styles) this hand-written one doesn't know about.

## Google Sign-In — real code exists, but needs your own setup to work

Beyond the OAuth client ID and backend `GOOGLE_CLIENT_ID` covered in
`README.md`, Android specifically needs:

1. A real `google-services.json` (from your own Google Cloud/Firebase
   project) placed in `android/app/`.
2. The Google Services Gradle plugin applied in
   `android/settings.gradle` (`id "com.google.gms.google-services" version "..."`
   in the `plugins` block) and `android/app/build.gradle`
   (`apply plugin: 'com.google.gms.google-services'` near the bottom,
   after the Flutter plugin).

Neither is included in this project's hand-built Gradle files —
adding the plugin reference without the real `google-services.json`
present would make the whole build fail outright, which is worse than
the current state (the app builds and runs fine without this
configured; only the "Sign in with Google" button fails until it is).
**For a demo, this is entirely skippable** — email/password
registration and login work without any of this.

## Push Notifications (FCM) — real code exists, but needs your own setup to work

Unlike Google Sign-In above, this does **not** need the Google Services Gradle plugin or a `google-services.json` at all — Firebase is initialized via explicit `FirebaseOptions` passed at build time (`core/configuration/firebase_config.dart`, `main.dart`), deliberately avoiding the exact same build-break risk described in the Google Sign-In section (the plugin reference needs the real JSON present, or the build fails outright). This keeps the native Gradle files exactly as committed — nothing to merge or regenerate here.

What `AndroidManifest.xml` already has, which needs no further setup: the `POST_NOTIFICATIONS` permission and a `com.google.firebase.messaging.default_notification_channel_id` meta-data entry (`chat_messages`).

What you provide at build/run time instead of a config file:

```
flutter run --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... --dart-define=FIREBASE_MESSAGING_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=...
```

All four come from a real Firebase project's Android app registration (Firebase Console → Project Settings → Your apps). The backend side needs `FIREBASE_SERVICE_ACCOUNT_KEY` (that project's service account JSON, as a string) in its `.env`. **For a demo, this is entirely skippable** — `Firebase.initializeApp()` is only called when all four values are present, so the app builds and runs normally with push simply disabled; chat still works fully via its existing 5-second poll.

## Content Moderation (Google Cloud Vision) — backend-only, no Android changes

The strict produce-photo check and general chat moderation (see README.md's "Content Moderation & Strict Produce-Photo Validation") both call Google Cloud Vision from the backend only — nothing in this section touches Gradle, the manifest, or any Android resource. Set `GOOGLE_CLOUD_VISION_API_KEY` in the **backend's** `.env` (see `nagaguno-backend/.env.example`) to enable it. **Skippable for a demo**: both checks fail open when the key is unset, and the on-device face/produce check (ML Kit, covered next) still runs regardless, with no override, using nothing this key provides.

The on-device half of that same check (`ml/image_validation/face_presence_detector.dart`, `produce_classifier.dart`) needs **no setup beyond what KYC liveness already requires** — it reuses the same `google_mlkit_face_detection` package already in `pubspec.yaml`, with its model fetched/managed by Google Play Services the same way the existing liveness face-detector already is. If KYC liveness works on your build, this works too, with nothing further to configure.

## Referenced Android resources that depend entirely on `flutter create` generating them

`AndroidManifest.xml` references three resources that used to not exist as actual files anywhere in this project: `@mipmap/ic_launcher` (the launcher icon), and `@style/LaunchTheme`/`@style/NormalTheme`. **Closed** — `flutter create --platforms=android .` generated Flutter's own default resource set at these exact names once a real toolchain was available (see below). No real NagaGuno-branded icon or theme exists yet — that needs actual logo/design artwork this environment doesn't have — but Flutter's defaults are a completely reasonable stand-in for a demo; swap in real branding later via `flutter_launcher_icons` and a custom `styles.xml` if it becomes important.

**A real warning for next time `flutter create .` is run against this project**: it doesn't only fill in missing files — it also wrote THREE conflicting duplicates that had to be found and deleted by hand: `android/build.gradle.kts`, `android/app/build.gradle.kts`, and `android/settings.gradle.kts` (recent Flutter defaults to Kotlin DSL; this project's real, hand-verified Gradle config is the Groovy `.gradle` files sitting right next to them — having both in the same directory is a real conflict, not a style choice, and Gradle will get confused about which to use), plus a second `MainActivity.kt` at the WRONG package path (`com/nagaguno/nagaguno_mobile/` instead of the real `com/nagaguno/mobile/` that `build.gradle`'s actual `namespace`/`applicationId` use), plus a generic `test/widget_test.dart` (the default Flutter counter-app smoke test, asserting against a `MyApp` counter screen that doesn't exist in this real app — it would fail outright if run). All four were deleted after generation; re-running `flutter create .` will very likely recreate them, so check for and remove the same four categories again rather than assuming a clean re-run.

## What's actually been done, and what's left before a first build

**Done, for real, once a real Flutter toolchain and internet access became available mid-session**:

1. ~~Source the six font files~~ — **closed.** `Fraunces-Regular/Bold/Black.ttf` and `DMSans-Regular/Medium/Bold.ttf` were fetched for real from `fonts.gstatic.com` and committed to `assets/fonts/`.
2. ~~Run `flutter pub get`~~ — **done.** Caught and fixed a real version conflict between `google_mlkit_face_detection` and `google_mlkit_image_labeling`/`google_mlkit_commons` (see `pubspec.yaml`'s own comments on the exact versions).
3. ~~Run `flutter analyze`, then `flutter test`~~ — **done, both clean.** `flutter analyze` found and fixed real errors (not just lint): an undefined provider reference, a stale test asserting against a field removed from a model earlier in the session, and every `RadioListTile` migrated off the deprecated `groupValue`/`onChanged` API. `flutter test` — all 79 pass, after fixing a stale `KycIdType` test, an uninitialized-binding crash in a test, and two real bugs in `blink_state_machine_test.dart`'s own loop logic (not the state machine itself — see `README.md` for the full account).
4. ~~A real Android SDK/Android Studio/emulator~~ — **turned out to already be installed on this machine** (`flutter doctor` found Android SDK 36.1.0 at `C:\Android\Sdk`, build-tools 36.1.0, an emulator, and Android Studio's bundled JDK 21) — this document previously said otherwise, corrected here. `android/local.properties` auto-generated correctly pointing at it.
5. ~~Accept the Android SDK licenses~~ — **done**, explicitly at your direction. `flutter doctor` now reports all 8 SDK package licenses accepted.
6. ~~Generate the missing `res/` resources~~ — **done** via `flutter create --platforms=android .`, with the conflicting duplicates it also created found and removed (see the warning above).

**A real `flutter build apk --debug` succeeded** — the project actually builds now, for the first time ever:

```
√ Built build\app\outputs\flutter-apk\app-debug.apk
```

Getting there took three real, separate fixes, confirmed one at a time rather than assumed:

7. The sandboxed shell this agent's own commands run in genuinely can't build this project — every attempt from inside it failed with `java.io.IOException: Unable to establish loopback connection` (Gradle's daemon failing to open a local socket), even after licenses were accepted and resources existed, and even after trying `-Djava.net.preferIPv4Stack=true`, `--no-daemon`, and invoking `gradlew` directly. **Running the identical command in your own Terminal panel (`flutter build apk --debug`, a genuinely different, unsandboxed shell on the same machine) got past this entirely** — confirming it really was a restriction specific to the agent's own sandboxed tool-execution context, not the project, the SDK, or your license acceptance.
8. That real run then hit an actual, different, project-level error 18 minutes into compiling: `Duplicate class com.google.firebase.iid.FirebaseInstanceIdReceiver`, because some transitive dependency (most likely `google_sign_in`'s underlying Play Services libraries) still pulls in the old, deprecated `firebase-iid` artifact that `firebase_messaging`'s own newer artifact already supersedes. Fixed in `android/app/build.gradle` with `configurations.all { exclude group: "com.google.firebase", module: "firebase-iid" }` — Google's own documented fix for this exact conflict class (https://d.android.com/r/tools/classpath-sync-errors), not a guess.
9. The build's own output also flagged `ndkVersion` 27.0.12077973 as mismatched against what the `jni` plugin (an ML Kit transitive dependency) needs — bumped to the recommended 28.2.13676358 in the same file, per Flutter's own suggestion in the build output.

With both of those applied, the retry succeeded in under 2 minutes (most of the 18-minute first run was cold-cache compilation that's now cached). The APK is real: `build/app/outputs/flutter-apk/app-debug.apk`, ~219MB (large but expected for an unminified debug build bundling camera + two ML Kit models + Firebase).

**Run it on an Android emulator or physical device next.** For a genuine demo of the KYC liveness feature specifically, a physical device or an emulator with camera passthrough configured will show it working more convincingly than a plain emulator with a synthetic camera feed. This is the one piece of real verification `flutter analyze`/`flutter test`/a successful build genuinely can't substitute for — see README.md's note on `inputImageFromCameraImage` still being unverified against a real camera stream.
