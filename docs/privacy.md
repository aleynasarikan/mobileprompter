# Privacy

This document describes how CueLine uses the microphone and speech recognition. It is not a store-ready legal privacy policy.

## Scripts

Text you type, paste, or open is stored on the device (SQLite). CueLine does not upload scripts to a CueLine server. CueLine does not create user accounts.

## Microphone

The microphone is used only while playback is running, so the teleprompter can follow the words you speak. Listening stops when you pause or stop playback, leave the teleprompter screen, or send the app to the background, unless the floating prompter is on (see below).

CueLine does not keep audio recordings.

## Floating prompter (Android)

The floating prompter is optional and starts only when you turn it on in the prompter. While it is on:

- A small CueLine window stays on screen over other apps (Android "display over other apps" permission, which you grant in system settings).
- Speech following keeps running while another app, such as TikTok, Instagram, YouTube or the camera, is in front. Android shows its microphone indicator and a CueLine notification for as long as this runs.
- The window shows only your own script. CueLine does not read, capture or record the screen or content of other apps, and does not access their camera.
- No audio or video is saved, and nothing new is sent anywhere. Speech goes to the same system recognizer as in the normal prompter.

Closing the window, pausing in it, leaving the prompter or removing CueLine from recent apps stops it.

## Speech recognition

Speech-to-text is provided by the operating system:

- Android: the device speech recognizer (commonly Google speech services)
- iOS: Apple speech recognition

CueLine does not operate its own speech servers. The system recognizer may send audio over the network when an offline language pack is not installed. Whether that happens, and how that audio is handled, is controlled by the OS vendor—not by CueLine.

## Network

Internet permission is declared because the system speech recognizer may need a network connection, and because some Flutter plugins query network state. CueLine does not include its own analytics or advertising SDK.

## Permissions

- Android: `RECORD_AUDIO`, `INTERNET`; for the floating prompter `SYSTEM_ALERT_WINDOW` (display over other apps), `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MICROPHONE`
- iOS: microphone usage description and speech recognition usage description in `Info.plist`

## What this document is not

This is a description of current app behavior for developers and testers. Publishing on Google Play or the App Store still requires a hosted privacy policy URL and the developer’s own legal review.
