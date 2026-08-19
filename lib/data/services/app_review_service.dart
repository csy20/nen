import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

enum AppReviewOutcome { inApp, storeListing, failed }

/// Requests a Google Play in-app review, falling back to the public listing.
class AppReviewService {
  AppReviewService({
    InAppReview? inAppReview,
    IsReviewAvailableFn? isAvailableFn,
    RequestReviewFn? requestReviewFn,
    LaunchUrlFn? launchUrlFn,
    CanLaunchUrlFn? canLaunchUrlFn,
  }) : _isAvailable =
           isAvailableFn ??
           (inAppReview ?? InAppReview.instance).isAvailable,
       _requestReview =
           requestReviewFn ??
           (inAppReview ?? InAppReview.instance).requestReview,
       _launchUrl = launchUrlFn ?? _defaultLaunch,
       _canLaunchUrl = canLaunchUrlFn ?? canLaunchUrl;

  static const playStoreUrl =
      'https://play.google.com/store/apps/details?id=dev.csy20.nen';

  final IsReviewAvailableFn _isAvailable;
  final RequestReviewFn _requestReview;
  final LaunchUrlFn _launchUrl;
  final CanLaunchUrlFn _canLaunchUrl;

  Future<AppReviewOutcome> requestReview() async {
    try {
      if (await _isAvailable()) {
        await _requestReview();
        return AppReviewOutcome.inApp;
      }
    } catch (_) {
      // Fall through to the public Play Store listing.
    }
    return openPlayStoreListing();
  }

  Future<AppReviewOutcome> openPlayStoreListing() async {
    final uri = Uri.parse(playStoreUrl);
    try {
      if (await _canLaunchUrl(uri) && await _launchUrl(uri)) {
        return AppReviewOutcome.storeListing;
      }
    } catch (_) {}
    return AppReviewOutcome.failed;
  }

  static Future<bool> _defaultLaunch(Uri url) {
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

typedef IsReviewAvailableFn = Future<bool> Function();
typedef RequestReviewFn = Future<void> Function();
typedef LaunchUrlFn = Future<bool> Function(Uri url);
typedef CanLaunchUrlFn = Future<bool> Function(Uri url);
