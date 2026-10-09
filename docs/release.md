# Release

CueLine ships as `app.cueline.teleprompter` on Android and iOS.

Version is set in `pubspec.yaml` (`versionName+versionCode`, currently `1.0.0+1`). Android ABI splits multiply `versionCode` by 10 and add an ABI offset.

## Android signing

Release APKs and App Bundles must be signed with an upload keystore that is **not** in git.

1. Create a keystore locally (do not commit it):

```bash
keytool -genkey -v -keystore android/keystore/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. Copy `android/key.properties.example` to `android/key.properties` and fill in the passwords and paths.

3. `android/key.properties`, `*.jks`, and `*.keystore` are gitignored.

Without `key.properties`, `flutter build apk --release` still produces an APK (unsigned or with the debug debug-keystore fallback that Gradle prints). Play Console requires the Play App Signing upload key. Do not invent credentials.

`flutter build appbundle --release` can complete a binary, but uploading it to Play still needs the real keystore and a Google Play Developer account.

Minification (R8) is left off. Enable it only after a signed release has been smoke-tested on a device.

## Android build

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
```

## Google Play: floating prompter declarations

The floating prompter adds these permissions:

| Permission | Why |
| --- | --- |
| `SYSTEM_ALERT_WINDOW` | Small prompter window over the app the user records with. Granted by the user in system settings; CueLine explains it first and works without it. |
| `FOREGROUND_SERVICE` | Required for any foreground service. |
| `FOREGROUND_SERVICE_MICROPHONE` | Speech following continues while CueLine is in the background. The service type is `microphone`; it is started only from the prompter while CueLine is on screen (Android 14+ does not allow creating it from the background). |

Before uploading a build that targets Android 14+ to Play:

1. Play Console → App content → Foreground service permissions: declare the `microphone` type. Use case: background audio access ("capture audio input ... without saving"). Description: "While the user records a video in another app, CueLine listens to the user reading their script and moves a small on-screen prompter along with the spoken words. Audio is not saved." User impact if deferred: "The prompter stops following the speaker mid-recording."
2. Attach a short video: open a script, start the prompter, tap the floating prompter button, allow display over other apps, switch to a camera app, speak, show the window following and the ongoing CueLine notification, pause and close it.
3. `SYSTEM_ALERT_WINDOW` has no separate Play declaration form, but reviewers check that the overlay is user-initiated, disclosed and dismissible. Keep the in-app explanation and the privacy policy section in sync.
4. The hosted privacy policy must describe the floating prompter (see `docs/privacy.md`).

`specialUse` is not used, so no special-use review text is needed.

## iOS

The Xcode project uses bundle identifier `app.cueline.teleprompter`.

Microphone and speech recognition usage strings are in `ios/Runner/Info.plist`.

Shipping to the App Store requires:

- Xcode on a Mac
- An Apple Developer account
- Signing certificates and a provisioning profile
- An App Store Connect listing, privacy nutrition labels, and a hosted privacy policy URL

This repository cannot complete those steps.

## Store checklist that stays outside the repo

- Google Play Developer account, Play App Signing, store listing, screenshots, content rating, privacy policy URL
- Apple Developer account, certificates, App Store listing, privacy nutrition labels, review notes for microphone / speech
- Physical-device QA of speech following
- Physical-device QA of the floating prompter (see `docs/progress.md`)
