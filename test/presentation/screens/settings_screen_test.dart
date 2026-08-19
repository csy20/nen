import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nen/data/services/app_review_service.dart';
import 'package:nen/presentation/providers/di_providers.dart';
import 'package:nen/presentation/screens/settings_screen.dart';
import 'package:nen/presentation/theme/nen_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Rate this app is in Settings and requests a review on tap', (
    tester,
  ) async {
    var requested = 0;
    final service = AppReviewService(
      isAvailableFn: () async => true,
      requestReviewFn: () async {
        requested++;
      },
      canLaunchUrlFn: (_) async => true,
      launchUrlFn: (_) async => true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appReviewServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: NenTheme.buildDark(),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('rate_this_app')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Rate this app'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rate_this_app')));
    await tester.pump();
    await tester.pump();

    expect(requested, 1);
  });
}
