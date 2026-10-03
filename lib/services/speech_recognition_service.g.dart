// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'speech_recognition_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(speechRecognitionService)
final speechRecognitionServiceProvider = SpeechRecognitionServiceProvider._();

final class SpeechRecognitionServiceProvider
    extends
        $FunctionalProvider<
          SpeechRecognitionService,
          SpeechRecognitionService,
          SpeechRecognitionService
        >
    with $Provider<SpeechRecognitionService> {
  SpeechRecognitionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'speechRecognitionServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$speechRecognitionServiceHash();

  @$internal
  @override
  $ProviderElement<SpeechRecognitionService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SpeechRecognitionService create(Ref ref) {
    return speechRecognitionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SpeechRecognitionService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SpeechRecognitionService>(value),
    );
  }
}

String _$speechRecognitionServiceHash() =>
    r'7d84ca6930809204c9035ad0ef4e0826a7a2ffbe';
