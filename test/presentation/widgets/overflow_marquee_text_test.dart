import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nen/presentation/widgets/overflow_marquee_text.dart';

void main() {
  Widget buildHarness({required double width, required String text}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: OverflowMarqueeText(text: text),
          ),
        ),
      ),
    );
  }

  testWidgets('renders plain text when the content fits', (tester) async {
    await tester.pumpWidget(buildHarness(width: 280, text: 'Short title'));

    expect(find.text('Short title'), findsOneWidget);
    expect(find.byType(ClipRect), findsNothing);
  });

  testWidgets('clips and animates long text without overflow', (tester) async {
    FlutterErrorDetails? overflowError;
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        overflowError = details;
      }
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(
      buildHarness(
        width: 120,
        text: 'Imagine Dragons - Demons - Very Long File Name Mix',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(ClipRect), findsOneWidget);
    expect(overflowError, isNull);
  });
}
