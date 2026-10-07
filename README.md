# CueLine

CueLine is a speech-following mobile teleprompter. Paste a script, tap Start, and speak. The app matches your words to the text, highlights the current word, and scrolls as you go.

It is based on [TiefPrompt](https://github.com/Tiefseetauchner/tiefprompt) by Lena Tauchner (MIT License).

## Features

- Speech-following karaoke highlighting (Turkish first; English when the device language is English)
- Manual seek that is not pulled back by delayed speech results
- Play / pause, speed control, and an optional countdown
- Adjustable font size, font family, alignment, and Markdown
- Horizontal or vertical flip for a physical teleprompter glass
- Scripts stored on the device
- English and Turkish UI, plus the original additional locales

If speech recognition is unavailable, Play falls back to auto-scroll.

Developer karaoke tools (word stepper, speech debug screen, Android overlay) stay off unless you pass `--dart-define=KARAOKE_DEBUG=true` in a **debug** build. They are never compiled into release.

## How speech tracking works

1. You open a script and tap **Start**.
2. CueLine asks for microphone permission if needed.
3. The operating-system speech recognizer returns partial and final text.
4. CueLine matches that text to the script around the current word and moves the highlight forward.
5. If you drag the text, tracking continues from the new reading line. Results from the previous utterance are ignored.

Speech recognition is provided by the OS (Google speech services on Android, Apple speech recognition on iOS). CueLine does not send audio to its own servers. See [docs/privacy.md](docs/privacy.md).

## Supported platforms

- **Android** — primary production target
- **iOS** — project is prepared; a Mac with Xcode and an Apple Developer account are required to ship

Desktop folders (macOS, Linux, Windows) remain from the upstream project and are not the current product focus.

## Development setup

```bash
flutter pub get
flutter analyze
flutter test
```

Run on a device:

```bash
flutter run
```

Karaoke debug tools:

```bash
flutter run --dart-define=KARAOKE_DEBUG=true
```

Use a physical device for speech recognition. Emulators are not reliable for STT.

## Tests

```bash
flutter test
```

## Release

See [docs/release.md](docs/release.md) for Android signing, Play / App Store notes, and known external blockers.

```bash
flutter build apk --release
flutter build appbundle --release
```

An Android App Bundle can be produced without a Play upload key, but Play Console will not accept an unsigned or debug-signed AAB. Configure `android/key.properties` from `android/key.properties.example` first.

## Known limitations

- On Android, Google speech recognition can close the session at the end of a sentence. CueLine restarts listening after a short delay; a brief gap or system beep is possible.
- Turkish recognition uses a network service unless an offline language pack is installed on the device.
- Store listing, screenshots, and signing credentials are not included in this repository.

## License

MIT. See [LICENSE](LICENSE).

CueLine includes third-party fonts and packages; font licenses are in `assets/licenses/`, and dependency licenses are listed in the in-app About / Licenses screen.
