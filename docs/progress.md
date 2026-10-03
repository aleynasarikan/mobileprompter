# İlerleme ve Devir Notları

Bu dosya, önceki sohbetlerde yapılan işin özetidir. Yeni bir sohbete buradan devam edin.
Ayrıntılı mimari analiz: `docs/architecture_analysis.md`.

## Hedef

TiefPrompt (MIT, Flutter) tabanlı, Türkçe konuşmayı takip eden mobil teleprompter. Öncelik Android MVP:
konuşma tanıma → metinle eşleştirme → otomatik ilerleme + karaoke vurgu, kelime atlamaya toleranslı.

## Tamamlanan aşamalar

### Aşama 0 — Analiz
- Rapor: `docs/architecture_analysis.md`.

### Aşama 1 — Karaoke renderer (tamam, Android'de test edildi)
- `lib/ui/widgets/karaoke_text.dart`
  - `KaraokeDocument`: metni bloklara ve kelimelere ayırır (global kelime indeksi, blok içi karakter aralığı, markdown inline stili). Markdown açıksa `tief_weave` AST'si kullanılır (paket değiştirilmedi), kapalıysa her satır bir blok.
  - `KaraokeController` (`ChangeNotifier`): `activeWordIndex` (-1 = başlamadı), `next/previous/reset`, debug timer (1000 ms).
  - `KaraokeText`: blok başına `Text.rich` + `RepaintBoundary`; yalnızca durumu değişen bloklar yeniden kurulur. Span yapısı `tief_weave` ile birebir (tam çözümlenmiş stil).
  - Stiller: okunmamış = normal, okunmuş = metin rengi %35 opaklık, aktif = `colorScheme.primary`. Arka plan/kutu yok, weight değişmez.
  - Scroll: aktif kelime görünüm alanının %15–75 dışına çıkınca %35 hizasına `animateTo` (300 ms).
  - `KaraokeDebugPanel`: önceki/oynat-duraklat/sonraki/sıfırla + 🎤 (speech debug ekranını açar).
- `lib/ui/widgets/scrollable_text.dart`: `ScrollableTextController.karaokeController` eklendi; `kKaraokeDebugMode` iken `KaraokeText` + debug paneli kullanılır; bölüm (chapter) offset'leri karaoke bloklarından okunur.
- `kKaraokeDebugMode = bool.fromEnvironment('KARAOKE_DEBUG', defaultValue: kDebugMode)` (release'de kapalı).

### Aşama 2 — Türkçe Speech-to-Text (kod tamam, kullanıcı emülatörde test edecek)
- Dependency: `speech_to_text: ^7.5.0` (`permission_handler` yok; izin isteğini plugin yapıyor).
- `lib/services/speech_recognition_service.dart`: initialize, `resolveLocale` (tercih `tr_TR`, yoksa aynı dil, liste boşsa yine `tr_TR`, yoksa sistem dili + uyarı), start/stop/pause/resume/cancel, olay akışı (`SpeechListeningChanged`, `SpeechResult`, `SpeechFailure`), sessizlikte otomatik yeniden başlatma (300 ms, en fazla 5 ardışık başarısız deneme). `speechRecognitionServiceProvider` (keepAlive).
- `lib/providers/speech_recognition_provider.dart`: freezed `SpeechRecognitionState` (`isListening`, `isActive`, `partialText`, `finalText`, `error`, `errorRecoverable`, `available`, `localeId`, `localeWarning`, ...), `speechRecognitionProvider` (autoDispose; dispose'da dinlemeyi iptal eder).
- `lib/ui/screens/speech_debug_screen.dart` + route `/speech_debug` (yalnızca debug). Açılış: teleprompter → sağ debug paneli → 🎤.
- `AndroidManifest.xml`: `RECORD_AUDIO`, `INTERNET`, `<queries>` içinde `android.speech.RecognitionService`.
- Debug APK derlemesi başarılı (`flutter build apk --debug -t lib/main_foss.dart`).

### Aşama 2b — STT/mikrofon teşhisi (kod tamam)
- Servis: `SpeechFailure.code`, `SpeechSoundLevel` (Android `onRmsChanged`), `SpeechDiagnostic`; `hasPermission()`; initialize'da izin reddi (`permission_denied`) ve `recognizerNotAvailable` ayrımı; stop/cancel `PlatformException` yakalanıyor; `listenFor` 60 sn, `pauseFor` 10 sn, `partialResults: true`.
- Provider: `permissionGranted`, `recognizerMissing`, `errorCode`, `sessionCount`, ses seviyesi min/max/olay sayısı, zaman damgalı olay günlüğü (son 50).
- Debug ekranı: Mic permission, RecognitionService, Sessions, Audio level, Audio input teşhisi, Event log satırları.
- Emülatör bulguları (Pixel_8, API 37): RECORD_AUDIO verilmiş; varsayılan tanıyıcı `com.google.android.tts/...GoogleTTSRecognitionService`; tr-TR için çevrimdışı paket yok (Soda hata 12) → tanıma çevrimiçi; ağ çalışıyor; sunucu "0 hypothesis" döndürüyor → oturumlar `error_no_match`/`error_speech_timeout` (kod 7) ile bitiyor. Emülatör host sesini alıyor (RMS -2…10 dB).
- Teşhis için: `adb logcat --pid=$(adb shell pidof com.google.android.tts)` (RecognitionClient, FinalS3RespProcessor, SodaSpeechRecognizer).

- Kullanıcı testi: emülatörde Türkçe partial/final sonuçlar geliyor (~10 dB).

### Aşama 3 — STT → karaoke eşleştirme MVP (kod + unit test tamam, cihaz testi kullanıcıda)
- `lib/services/karaoke_matcher.dart` (saf Dart): `normalizeTurkishWord` (İ→i, I→ı, â/î/û→a/i/u, noktalama/apostrof silinir), `tokenizeTurkish` (boşluk, tire, eğik çizgi), `foldTurkish` (yalnızca fuzzy için ş→s, ğ→g, ...), Levenshtein.
  - `KaraokeMatcher.match`: son 5 konuşulan token ile pencere (aktifin 6 gerisi / 40 ilerisi; başlangıçta ilk 50) arasında DP hizalama; kelime skoru exact 1.0, katlanmış eşit 0.9, fuzzy (≥ 4 harf, benzerlik ≥ 0.75) ×0.9; atlanan metin kelimesi −0.15. Güven = zincir skoru / bağlam uzunluğu. Yöntem: exact / sequence / fuzzy / none.
  - `KaraokeSpeechTracker`: partial'lar birbirinin yerine geçer (append yok); final commit edilir, son 5 token bir sonraki oturuma bağlam olur; aynı final tekrarlanırsa yok sayılır. Karar: güven < 0.6 tutulur; tek kelime en fazla 2 ileri; 10'dan büyük sıçrama güçlü eşleşme ister (≥ 3 kelime, ≥ 0.8); geri yönde 3 ardışık güçlü eşleşme gerekir; 4 ardışık zayıf sonuçta tüm metinde resync.
- `lib/services/karaoke_speech_follower.dart`: servis olaylarını tracker'a verir, `controller.activeWordIndex`'i günceller (yalnızca `speechMode` açıkken).
- `karaoke_text.dart`: `KaraokeDocument.words`, `KaraokeController.document`, `speechMode` (açıkken debug timer çalışmaz), panelde STT düğmesi. Görünüm değişmedi.
- `scrollable_text.dart` (yalnızca `kKaraokeDebugMode`): follower, `speechRecognitionProvider.isActive` → `speechMode`, sol üstte debug kutusu.
- Testler: `test/services/karaoke_matcher_test.dart` (19 test).

### Aşama 3b — STT oturum sürekliliği (kod tamam, cihaz testi kullanıcıda)
- Sorun (logcat ile ölçüldü): Google tanıyıcı her cümlede final veriyor; plugin'in Dart katmanı (`speech_to_text.dart:680`) bir oturumda final sonrası tüm sonuçları düşürüyor ve oturum ancak pause zamanlayıcısıyla kapanıyordu → final ile yeni oturum arasında 7–8 sn ölü süre.
- `speech_recognition_service.dart`: `pauseFor` 10 → 2 sn; final `SpeechResult` gelince `_restartAfterFinal` oturumu hemen `stop` eder ve `_restartDelay` (300 ms) sonra yeniden `listen` eder. `_listenInFlight` / `_stopInFlight` bayrakları çift `listen` ve stop/listen çakışmasını engeller; `done` ile planlanan restart aynı zamanlayıcıyı kullandığı için tek `listen` olur.
- Eşleştirici bilinçli olarak değiştirilmedi (bağlam boyutu, eşikler, +1 öngörü sonraya).
- Kullanıcı testi: 7–8 sn boşluk gitti; ama her finalde bip + 1–2 sn duraksama var (Google oturumu final sonrası açık tutuyor, biz kapatıyoruz). Çözüm önerisi (henüz uygulanmadı): platform callback'lerini doğrudan dinle, finalde stop yapma, yalnızca gerçek oturum sonunda/RMS kesilince restart.

### Aşama 4 — Manuel seek ve matcher senkronu (kod + test tamam, cihaz testi kullanıcıda)
- Doğruluk kaynağı `KaraokeController.activeWordIndex`. STT servisi ve eşikler değişmedi.
- `karaoke_text.dart`: `seek(index)` (her çağrıda `seekCount++` ve bildirim), `next/previous/reset` artık seek; debug timer seek değil. `seekToReadingLine()`: okuma çizgisindeki (görünümün %35'i = `revealAlignment`) satırın ilk kelimesini bulur, `active = o kelime − 1` yapar (sıradaki okunacak kelime o olur; metnin üstü → −1, altı → son kelime). `isUserScrolling` true iken `_revealActiveWord` kaydırmaz.
- `scrollable_text.dart`: `ScrollableTextController.jumpTo/jumpRelative` → post-frame `seekToReadingLine`. Sürükleme başında `isUserScrolling = true`; sürüklemeden (fling dahil) sonraki `ScrollEndNotification`'da post-frame seek + bayrak false.
- `karaoke_speech_follower.dart`: controller'ı dinler; `seekCount` değiştiyse ya da `activeWordIndex` follower'ın kendi yazdığı değerden farklıysa manuel seek sayar → `tracker.resetContext(pendingPartial: o anki partial)`. Sürükleme sırasında sonuçları uygulamaz. `SpeechListeningChanged(listening)` → `tracker.onSessionStart()`.
- `karaoke_matcher.dart` (`KaraokeSpeechTracker`): `resetContext` committed bağlamı ve streak'leri siler; o anki birikimli partial'ın tokenlarını "eski" işaretler, aynı söyleyişin sonraki partial/final'ında bu önek atlanır (ilk kelime farklıysa ya da yeni oturumda iptal). Eşleşme kuralları/eşikler aynı.
- Testler: `karaoke_matcher_test.dart` (+10 seek testi), yeni `test/ui/karaoke_seek_test.dart` (okuma çizgisi, düğmeler, follower algılama, sürükleme) — 42 test geçiyor.
- Not: açılışta kayıtlı scroll konumuna `jumpTo` da seek sayılır; aktif kelime o konumdan başlar (varsayılan konumda yine −1).

### Aşama 4b — Seek sonrası gecikmeli STT regresyonu (kod + test tamam)
- Problem: seek sonrasında gecikmeli eski STT partial/final sonuçları yeni konuşma gibi işleniyor ve aktif kelimeyi eski konuma sıçratıyordu.
- İkinci problem: seek sonrasında aynı final metni `_lastFinal` yüzünden duplicate kabul edilip yok sayılıyordu.
- Kök neden: seek sırasında eski utterance yalnızca o andaki partial ile takip ediliyordu; `_lastFinal` seek'te temizlenmiyordu.
- Çözüm: `karaoke_speech_follower.dart` içinde `_ignoreUtterance`. Seek anında açık utterance varsa final'a kadar sonuçlar tracker'a gitmez. `karaoke_matcher.dart` içinde `resetContext()` `_lastFinal`'ı temizler.
- Sürükleme davranışı aynı: sürüklerken kelime ilerlemez, bırakınca okuma çizgisine seek edilir.
- Testler: gecikmiş eski partial/final, seek sonrası aynı final, gerçek drag/seek, seek sırasında açık utterance, seek sırasında açık utterance yokken yeni speech, ilgili karaoke testleri.
- Sonuç: 54/54 test geçti.

## Sıradaki adımlar
1. Aşama 4 cihaz testi: STT açıkken elle geri/ileri sar, başa al, panel düğmeleri; takip yeni konumdan devam etmeli.
2. STT oturum sürekliliği v2 (bip/1–2 sn duraksama): yukarıdaki öneri; önce logcat ile final sonrası partial'ların yalnızca yeni cümleyi içerdiğini doğrula.
3. Yanlış söyleme/resync: zayıf eşleşmede yalnızca taze tokenlarla ikinci deneme; eski bağlamın tek başına hareket ettirmemesi.
4. Sesle takip modunda sabit hızlı Ticker kaydırmasının devre dışı kalması.
4. Sonra: modern UI, dikey yön, applicationId, iOS izinleri (Info.plist), çevrimdışı STT değerlendirmesi.

## Çalışma kuralları (kullanıcı tercihleri)
- İletişim Türkçe. Her aşama dar kapsamlı; kullanıcı açıkça istemedikçe kapsam dışı işe (UI, applicationId, iOS, yeni dependency) dokunma.
- İş bitince: değişen dosyalar, neden, nasıl test edilir — kısa özet.
- `tief_weave` paketini değiştirme.

## Bilinen tuzaklar
- `build_runner`'ı `--build-filter` ile çalıştırma: diğer tüm üretilmiş dosyaları siliyor. Tam `dart run build_runner build` kullan (sonra `git status` kontrol et).
- `flutter`/`dart` komutları sandbox dışında çalıştırılmalı (Flutter SDK cache'ine yazıyor).
- `main_freemium.dart` zincirinde önceden var olan analiz hataları var (`in_app_purchase` yorum satırında); `main.dart`/`main_foss.dart` etkilenmiyor.
- `router_provider.g.dart` hash'i yeniden üretilmedi (zararsız).
- Android sürekli dinleme: oturum sessizlikte biter, yeniden başlatmada bip sesi ve birkaç kelime kaybı olabilir.
- Plugin `listening` durumunu `startListening` post edilir edilmez bildirir; "Listening: ON" mikrofonun ses aldığını kanıtlamaz, ses seviyesi olaylarına bakılmalı.
- Plugin, `error_no_match` hatasını max RMS < 9 ise `error_speech_timeout` olarak raporlar.
- Emülatör: Extended Controls → Microphone → "Virtual microphone uses host audio input" her açılışta kapanabilir; macOS'ta emülatöre mikrofon izni gerekir.
