import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cueline/services/creator_mode.dart';
import 'package:cueline/services/creator_overlay.dart';

void main() {
  group('planCreatorSync', () {
    test('hidden mode sends nothing', () {
      final plan = planCreatorSync(
        visible: false,
        words: const ['merhaba'],
        activeWordIndex: 0,
        sentWords: null,
        sentIndex: null,
      );
      expect(plan.kind, CreatorSyncKind.none);
    });

    test('the first frame sends the whole script', () {
      final plan = planCreatorSync(
        visible: true,
        words: const ['merhaba', 'dünya'],
        activeWordIndex: -1,
        sentWords: null,
        sentIndex: null,
      );
      expect(plan.kind, CreatorSyncKind.show);
      expect(plan.activeWordIndex, -1);
    });

    test('a new active word sends only the index', () {
      final plan = planCreatorSync(
        visible: true,
        words: const ['merhaba', 'dünya'],
        activeWordIndex: 1,
        sentWords: const ['merhaba', 'dünya'],
        sentIndex: 0,
      );
      expect(plan.kind, CreatorSyncKind.update);
      expect(plan.activeWordIndex, 1);
    });

    test('an edited script sends the words again', () {
      final plan = planCreatorSync(
        visible: true,
        words: const ['yeni', 'metin'],
        activeWordIndex: 0,
        sentWords: const ['merhaba', 'dünya'],
        sentIndex: 0,
      );
      expect(plan.kind, CreatorSyncKind.show);
    });

    test('the same position sends nothing', () {
      final plan = planCreatorSync(
        visible: true,
        words: const ['merhaba'],
        activeWordIndex: 0,
        sentWords: const ['merhaba'],
        sentIndex: 0,
      );
      expect(plan.kind, CreatorSyncKind.none);
    });
  });

  group('CreatorMode', () {
    test('follows the stage script and then only the active word', () async {
      final source = _Source();
      final overlay = _FakeOverlay();
      final mode = CreatorMode(overlay);
      addTearDown(mode.dispose);

      mode.attach(
        listenable: source,
        words: () => source.words,
        index: () => source.index,
      );
      await mode.show(useMicrophone: true);

      expect(overlay.shows.single.words, ['bir', 'iki', 'üç']);
      expect(overlay.shows.single.index, -1);
      expect(overlay.shows.single.mic, isTrue);

      source.move(1);
      await mode.pending;
      expect(overlay.updates, [1]);
      expect(overlay.shows, hasLength(1));

      source.replace(['yeni', 'metin']);
      await mode.pending;
      expect(overlay.shows.last.words, ['yeni', 'metin']);
      expect(overlay.shows.last.index, 1);
    });

    test('uses fallback words until the stage script exists', () async {
      final overlay = _FakeOverlay();
      final mode = CreatorMode(overlay);
      addTearDown(mode.dispose);

      mode.setFallbackWords(['sabit', 'metin']);
      await mode.show(useMicrophone: false);

      expect(overlay.shows.single.words, ['sabit', 'metin']);
      expect(overlay.shows.single.mic, isFalse);
    });

    test('hide stops further updates', () async {
      final source = _Source();
      final overlay = _FakeOverlay();
      final mode = CreatorMode(overlay);
      addTearDown(mode.dispose);
      mode.attach(
        listenable: source,
        words: () => source.words,
        index: () => source.index,
      );
      await mode.show(useMicrophone: false);
      await mode.hide();

      source.move(2);
      await mode.pending;

      expect(overlay.hides, 1);
      expect(overlay.updates, isEmpty);
      expect(mode.isVisible, isFalse);
    });
  });
}

class _Source extends ChangeNotifier {
  List<String> words = ['bir', 'iki', 'üç'];
  int index = -1;

  void move(int next) {
    index = next;
    notifyListeners();
  }

  void replace(List<String> next) {
    words = next;
    notifyListeners();
  }
}

class _FakeOverlay implements CreatorOverlayApi {
  final shows = <({List<String> words, int index, bool mic})>[];
  final updates = <int>[];
  var hides = 0;

  @override
  Future<bool> canDrawOverlays() async => true;

  @override
  Future<void> openOverlaySettings() async {}

  @override
  Future<bool> isRunning() async => false;

  @override
  Future<void> show({
    required List<String> words,
    required int activeWordIndex,
    required bool useMicrophone,
  }) async {
    shows.add((words: words, index: activeWordIndex, mic: useMicrophone));
  }

  @override
  Future<void> update(int activeWordIndex) async {
    updates.add(activeWordIndex);
  }

  @override
  Future<void> hide() async {
    hides++;
  }
}
