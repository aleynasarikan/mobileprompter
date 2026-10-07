# Privacy

This document describes how CueLine uses the microphone and speech recognition. It is not a store-ready legal privacy policy.

## Scripts

Text you type, paste, or open is stored on the device (SQLite). CueLine does not upload scripts to a CueLine server. CueLine does not create user accounts.

## Microphone

The microphone is used only while playback is running, so the teleprompter can follow the words you speak. Listening stops when you pause or stop playback, leave the teleprompter screen, or send the app to the background.

CueLine does not keep audio recordings.

## Speech recognition

Speech-to-text is provided by the operating system:

- Android: the device speech recognizer (commonly Google speech services)
- iOS: Apple speech recognition

CueLine does not operate its own speech servers. The system recognizer may send audio over the network when an offline language pack is not installed. Whether that happens, and how that audio is handled, is controlled by the OS vendor—not by CueLine.

## Network

Internet permission is declared because the system speech recognizer may need a network connection, and because some Flutter plugins query network state. CueLine does not include its own analytics or advertising SDK.

## Permissions

- Android: `RECORD_AUDIO`, `INTERNET`
- iOS: microphone usage description and speech recognition usage description in `Info.plist`

## What this document is not

This is a description of current app behavior for developers and testers. Publishing on Google Play or the App Store still requires a hosted privacy policy URL and the developer’s own legal review.
