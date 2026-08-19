import 'package:flutter_test/flutter_test.dart';
import 'package:nen/data/services/app_review_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses in-app review when the API is available', () async {
    var requested = false;
    final service = AppReviewService(
      isAvailableFn: () async => true,
      requestReviewFn: () async {
        requested = true;
      },
      canLaunchUrlFn: (_) async => true,
      launchUrlFn: (_) async => true,
    );

    final outcome = await service.requestReview();

    expect(outcome, AppReviewOutcome.inApp);
    expect(requested, isTrue);
  });

  test('falls back to Play Store URL when in-app review is unavailable',
      () async {
    Uri? launched;
    final service = AppReviewService(
      isAvailableFn: () async => false,
      requestReviewFn: () async {},
      canLaunchUrlFn: (_) async => true,
      launchUrlFn: (uri) async {
        launched = uri;
        return true;
      },
    );

    final outcome = await service.requestReview();

    expect(outcome, AppReviewOutcome.storeListing);
    expect(launched.toString(), AppReviewService.playStoreUrl);
  });

  test('falls back to Play Store URL when in-app review throws', () async {
    Uri? launched;
    final service = AppReviewService(
      isAvailableFn: () async => throw StateError('unavailable'),
      requestReviewFn: () async {},
      canLaunchUrlFn: (_) async => true,
      launchUrlFn: (uri) async {
        launched = uri;
        return true;
      },
    );

    final outcome = await service.requestReview();

    expect(outcome, AppReviewOutcome.storeListing);
    expect(launched.toString(), AppReviewService.playStoreUrl);
  });

  test('returns failed when the store listing cannot be opened', () async {
    final service = AppReviewService(
      isAvailableFn: () async => false,
      requestReviewFn: () async {},
      canLaunchUrlFn: (_) async => false,
      launchUrlFn: (_) async => true,
    );

    expect(await service.requestReview(), AppReviewOutcome.failed);
  });
}
