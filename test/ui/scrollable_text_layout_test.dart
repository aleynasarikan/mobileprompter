import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cueline/providers/prompter_provider.dart';
import 'package:cueline/services/speech_recognition_service.dart';
import 'package:cueline/ui/widgets/scrollable_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late ScrollableTextController scrollable;

  Future<void> pumpPrompter(
    WidgetTester tester, {
    double height = 220,
    double initialOffset = 0,
    String? text,
  }) async {
    container = ProviderContainer(
      overrides: [
        speechRecognitionServiceProvider.overrideWithValue(
          SpeechRecognitionService(),
        ),
      ],
    );
    scrollable = ScrollableTextController(initialScrollOffset: initialOffset);
    addTearDown(container.dispose);
    addTearDown(scrollable.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: height,
              child: ScrollableText(
                controller: scrollable,
                text:
                    text ??
                    'Merhaba dünya bu bir deneme metnidir ve devam eder '
                        'ikinci satır üçüncü satır dördüncü satır beşinci satır',
                sideMargin: 0,
                style: const TextStyle(fontSize: 28, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the script starts inside the scroll viewport', (tester) async {
    await pumpPrompter(tester);

    final scrollRect = tester.getRect(find.byType(SingleChildScrollView));
    final textRect = tester.getRect(find.byType(RichText).first);
    expect(
      textRect.top,
      lessThan(scrollRect.bottom),
      reason: 'first line is below the fold',
    );
    expect(
      textRect.bottom,
      greaterThan(scrollRect.top),
      reason: 'first line is above the fold',
    );
  });

  testWidgets('a saved offset past the script is brought back', (tester) async {
    await pumpPrompter(tester, initialOffset: 4000);

    final scrollRect = tester.getRect(find.byType(SingleChildScrollView));
    final textRect = tester.getRect(find.byType(RichText).first);
    expect(textRect.top, lessThan(scrollRect.bottom));
    expect(textRect.bottom, greaterThan(scrollRect.top));
  });

  testWidgets('the microphone does not roll the script on a timer', (
    tester,
  ) async {
    await pumpPrompter(tester);
    scrollable.karaokeController.speechMode = true;

    container.read(prompterProvider.notifier).togglePlayPause();
    await tester.pump();
    final before = scrollable.scrollController.offset;
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(scrollable.scrollController.offset, before);
  });

  testWidgets('a recognized word pulls the script to the reading line', (
    tester,
  ) async {
    await pumpPrompter(
      tester,
      text: List.generate(40, (i) => 'kelime$i').join('\n'),
    );
    scrollable.karaokeController.speechMode = true;
    container.read(prompterProvider.notifier).togglePlayPause();
    await tester.pump();
    final before = scrollable.scrollController.offset;

    scrollable.karaokeController.activeWordIndex = 25;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(scrollable.scrollController.offset, greaterThan(before + 20));
  });
}
