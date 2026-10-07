import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cueline/ui/widgets/karaoke_text.dart';

void main() {
  for (final paragraphWords in [5000, 60]) {
    testWidgets('advance cost, paragraph=$paragraphWords', (tester) async {
      final words = List.generate(5000, (i) => 'kelime$i');
      final buffer = StringBuffer();
      for (var i = 0; i < words.length; i++) {
        buffer.write(words[i]);
        buffer.write((i + 1) % paragraphWords == 0 ? '\n' : ' ');
      }
      final controller = KaraokeController();
      final scroll = ScrollController();
      final sw = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: KaraokeText(
                text: buffer.toString(),
                controller: controller,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
        ),
      );
      final firstBuild = sw.elapsedMilliseconds;
      sw.reset();
      for (var i = 0; i < 200; i++) {
        controller.activeWordIndex = 2000 + i;
        await tester.pump();
      }
      // ignore: avoid_print
      print(
        'paragraph=$paragraphWords first=${firstBuild}ms '
        'perWord=${(sw.elapsedMicroseconds / 200 / 1000).toStringAsFixed(2)}ms',
      );
      await tester.pumpAndSettle();
      controller.dispose();
      scroll.dispose();
    });
  }
}
