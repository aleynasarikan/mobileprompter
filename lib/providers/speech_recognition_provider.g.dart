// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'speech_recognition_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SpeechRecognition)
final speechRecognitionProvider = SpeechRecognitionProvider._();

final class SpeechRecognitionProvider
    extends $NotifierProvider<SpeechRecognition, SpeechRecognitionState> {
  SpeechRecognitionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'speechRecognitionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$speechRecognitionHash();

  @$internal
  @override
  SpeechRecognition create() => SpeechRecognition();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SpeechRecognitionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SpeechRecognitionState>(value),
    );
  }
}

String _$speechRecognitionHash() => r'6978bb82f9314971a31dd1c5e5209ff683b95e15';

abstract class _$SpeechRecognition extends $Notifier<SpeechRecognitionState> {
  SpeechRecognitionState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<SpeechRecognitionState, SpeechRecognitionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SpeechRecognitionState, SpeechRecognitionState>,
              SpeechRecognitionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
