# İlerleme ve Devir Notları

Bu dosya, önceki sohbetlerde yapılan işin özetidir. Yeni bir sohbete buradan devam edin.
Ayrıntılı ilk mimari analiz (tarihi): `docs/architecture_analysis.md`.
Gizlilik davranışı: `docs/privacy.md`.
Yayın notları: `docs/release.md`.

## Hedef

CueLine — TiefPrompt (MIT, Flutter) tabanlı, konuşmayı takip eden mobil teleprompter.
Android ve iOS: konuşma tanıma → metinle eşleştirme → otomatik ilerleme + karaoke vurgu.
Kelime atlamaya ve manuel seek’e toleranslı.

## Ürün kimliği

- Görünen ad: **CueLine**
- Dart paketi: `cueline`
- Android `applicationId` / namespace: `app.cueline.teleprompter`
- iOS / macOS bundle ID: `app.cueline.teleprompter`
- Sürüm: `1.0.0+1`

## Production MVP durumu

Karaoke renderer, matcher, seek koruması ve STT servisi **release build’de açıktır**.
Play mikrofonu başlatır; STT yoksa otomatik kaydırmaya düşer.

### Speech pipeline

`SpeechRecognitionService` (`speech_to_text`) → `KaraokeSpeechFollower` → `KaraokeSpeechTracker` / `KaraokeMatcher` → `KaraokeController.activeWordIndex` → `KaraokeText`.

- Tanıma dili script’ten seçilir (`preferredSpeechLocaleIdForScript`): metinde Türkçe harf (ç ğ ı ö ş ü İ) varsa `tr_TR`, yoksa cihaz İngilizce ise `en_US`, aksi halde `tr_TR`. Yalnızca cihaz diline bakmak İngilizce cihazda Türkçe metni İngilizce tanıyordu.
- Partial’lar oturum içinde birbirinin yerine geçer; final commit edilir.
- Final gelince oturum hemen `cancel()` ile kapatılır ve 300 ms sonra tek bir `listen` açılır. Plugin final sonrası oturumun diğer sonuçlarını atar; Google’ın sürekli tanıyıcısı oturumu kendisi kapatmayabilir. `stop()` değil `cancel()`: konuşmacı sonraki cümledeyken `stop()` gelirse tanıyıcı `onEndOfSpeech`’i sonradan yollar, plugin’in end-of-speech zamanlayıcısı *yeni* oturumu “dinlemiyor” işaretler; tanıyıcı hâlâ meşgul olduğundan her `listen` `error_client` ile düşer ve 5 denemeden sonra tanıma kapanır (Pixel 8 emülatöründe yeniden üretildi).
- Plugin’e `listenFor`/`pauseFor` verilmez: plugin bunları kendi `stop()`’u ile uygular ve aynı zamanlayıcı sorununu tetikler.
- Sessizlikte oturum `done`/hata ile kapanınca kontrollü `listen`. Ardışık sessizlikte restart gecikmesi artar (en fazla 2.4 s).
- Eski recognizer oturumundan gelen delayed partial/final yeni oturuma uygulanmaz (`session != _generation`).
- Uygulama arka plana alınca `pause()` motoru durdurur ama `isActive` kalır; `done` arka planda yeniden dinleme açmaz. Öne dönünce `resume()`.
- Prompter ekranından çıkınca dinleme `stop()` ile kapanır. `State.dispose` içinde `ref` kullanılamaz (Riverpod 3 `StateError`); servis `initState`’te alana alınır.

### Karaoke matching (bozulmamalı sözleşmeler)

- `_committed` kuyruğu (son 5 token); zincire girmeyen committed tokenlar confidence paydasından çıkar.
- `minConfidence` 0.6; tek kelime en fazla +2; 10’dan büyük sıçrama güçlü eşleşme ister (≥3 kelime, ≥0.8).
- Geri eşleşme: 3 ardışık güçlü sonuç.
- `resetContext(pendingPartial:)` seek sonrası eski bağlamı siler; `_lastFinal` temizlenir.
- Follower: seek sırasında açık utterance varsa `_ignoreUtterance` ile final’a kadar sonuçlar tracker’a gitmez.

### Seek

Doğruluk kaynağı `KaraokeController.activeWordIndex`. Elle kaydırma bitince okuma çizgisine (`revealAlignment` %35) `seekToReadingLine`. Sürüklerken `isUserScrolling` kaydırmayı ve konuşma ilerlemesini durdurur; durum çubuğunda “Tracking paused” görünür.

İlk satır, kaydırma alanının %35’inde durur (ekran yüksekliği kadar boşluk yok). Mikrofon açıkken hız kaydırması durur; tanınan kelime okuma çizgisine gelir. Tanıma kapalıysa hız kaydırmasına düşülür.

### UI

CueLine design system: tek amber vurgu (`#E8B44C`), nötr koyu zemin, Roboto UI fontu, token’lar `lib/ui/theme/cueline_tokens.dart`.

- Home: wordmark + kısa tagline + kenarlıksız editör + **Prova başlat**.
- Prompter: content-first koyu chrome, play CTA, Aa / tune / more progressive disclosure. Portrait + landscape. Karaoke vurgu: okunmuş %42 opaklık, aktif = accent, ağırlık değişmez.
- Settings: Appearance / Prompter / About grupları.
- About / Privacy: CueLine kimliği; MIT / TiefPrompt attribution korunur.
- Debug şeridi / speech debug / log: yalnızca `--dart-define=KARAOKE_DEBUG=true`.

### Yüzen prompter (Android)

Prompter üst çubuğundaki düğme açar. Yalnızca Android 8+; iOS’ta düğme görünmez.

- Tek pipeline: STT → follower → matcher → `KaraokeController` → (prompter UI + `CreatorMode` → native pencere). Pencere yalnızca kelimeleri bir kez, sonra aktif index’i alır; art arda değişiklikler tek güncellemeye iner.
- Durumlar (`FloatingPrompter`): off → permissionRequired (açıklama, “Şimdi değil”) → awaitingPermission (sistem ayarı) → starting → active; hata → failed. Duraklatma ayrı durum değil, prompter’ın play durumunu izler.
- Native: `CreatorOverlayService`, `microphone` tipinde foreground service + `TYPE_APPLICATION_OVERLAY` pencere (oynat/duraklat, kapat, sürükle). Mikrofon FGS’i Android 14+’da arka plandan oluşturulamaz; düğmeye basıldığında, CueLine ekrandayken başlatılır. Başladıktan sonra CueLine `moveTaskToBack` ile arka plana geçer.
- CueLine ön plandayken pencere gizlenir, arka plana geçince görünür. Pencere açıkken `PrompterScreen` arka planda konuşmayı duraklatmaz.
- Kapat: pencere ve servis durur, CueLine öne gelir. Prompter’dan çıkmak, uygulamayı son uygulamalardan kaldırmak (`stopWithTask`) veya activity’nin bitmesi de servisi durdurur.
- Emülatörde doğrulandı (Pixel 8, Android 16): izin akışı (reddet / ver), pencerenin ana ekran ve YouTube üzerinde görünmesi, arka planda STT partial’larının follower/matcher’a ulaşması, overlay’den duraklatma, kapatınca CueLine’a dönüş, süreç ölünce servisin kalmaması. Ortamdaki başka bir konuşma tanındığı için arka planda kelime ilerlemesi emülatörde gözlenemedi; gerçek cihaz QA’sı gerekli.
- iOS: başka uygulamaların üzerinde serbest pencere yok. PiP (`AVSampleBufferDisplayLayer`) ile metin göstermek teknik olarak mümkün ama video dışı içerik App Review riski taşır ve arka planda sürekli konuşma tanıma ayrıca doğrulanmalı; bu sürümde yok.

### Platform

- Android: `RECORD_AUDIO`, `INTERNET`, `RecognitionService` queries; yüzen prompter için `SYSTEM_ALERT_WINDOW`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`. Play beyanı: `docs/release.md`.
- iOS: `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`. Deployment 15.6.
- Store imzalama bu repoda yok; `android/key.properties.example` şablondur.

## Test

`flutter test` — matcher, tracker, follower/seek, STT restart/pause/session isolation, uzun oturum, drift.
`test/ui/prompter_speech_pipeline_test.dart` gerçek `PrompterScreen` üzerinden play → STT → follower → matcher → controller → KaraokeText → scroll zincirini, lifecycle’ı, seek’i ve landscape düzenini sınar (yalnızca plugin’ler fake).

## Bilinen sınırlamalar

- Android sürekli dinleme: cümle sonunda Google oturumu kapanır; yeniden başlatmada kısa boşluk / bip olabilir.
- Çevrimdışı Türkçe paketi cihazda yoksa tanıma ağa bağlıdır.
- Emülatörde STT güvenilir değildir; gerçek cihaz gerekir. Pixel 8 emülatöründe Türkçe tanıyıcı partial göndermez, yalnızca segment sonunda final verir; takip cümle blokları halinde ilerler.
- Store imzalama (Play upload key, Apple certificates) bu repoda yok.
- Hosted privacy policy URL ve store listing bu repoda yok.

## Çalışma kuralları

- İletişim Türkçe.
- `tief_weave` paketini değiştirme.
- `build_runner`'ı `--build-filter` ile çalıştırma.
- `flutter`/`dart` sandbox dışında.

## Debug bayrakları

```
flutter run --dart-define=KARAOKE_DEBUG=true
flutter run --dart-define=KARAOKE_TIMING=true
```
