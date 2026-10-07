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
