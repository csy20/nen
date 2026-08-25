import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nen/presentation/widgets/async_error_view.dart';

void main() {
  testWidgets('does not dump native stack traces to the user', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncErrorView(
            title: 'Error loading songs.',
            error: Exception(
              'PlatformException(error, lateinit property context has not been initialized, null)',
            ),
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Error loading songs.'), findsOneWidget);
    expect(find.textContaining('lateinit'), findsNothing);
    expect(find.textContaining('music library'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retried, isTrue);
  });
}
