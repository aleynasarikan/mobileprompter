import 'package:flutter/foundation.dart';

/// Developer tools for the karaoke pipeline: word stepping panel, match info
/// overlay, the speech debug screen and the Android creator overlay.
///
/// Off by default, also in debug builds. Enable with
/// `--dart-define=KARAOKE_DEBUG=true`. Never available in release builds.
const bool kKaraokeDebugTools =
    bool.fromEnvironment('KARAOKE_DEBUG') && !kReleaseMode;

/// `[KARAOKE_TIMING]` log lines. Enable with
/// `--dart-define=KARAOKE_TIMING=true`. Never available in release builds.
const bool kKaraokeTimingLog =
    bool.fromEnvironment('KARAOKE_TIMING') && !kReleaseMode;
