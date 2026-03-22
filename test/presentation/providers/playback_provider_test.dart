import 'package:flutter_test/flutter_test.dart';
import 'package:nen/presentation/providers/playback_provider.dart';

void main() {
  group('PlaybackFeedbackNotifier', () {
    test('show publishes a message and clear removes the matching event', () {
      final notifier = PlaybackFeedbackNotifier();
      addTearDown(notifier.dispose);

      notifier.show('Failed to play track');
      final firstMessage = notifier.state;

      expect(firstMessage, isNotNull);
      expect(firstMessage!.message, 'Failed to play track');

      notifier.clear(firstMessage.id + 1);
      expect(notifier.state, isNotNull);

      notifier.clear(firstMessage.id);
      expect(notifier.state, isNull);
    });

    test('new messages get unique ids', () {
      final notifier = PlaybackFeedbackNotifier();
      addTearDown(notifier.dispose);

      notifier.show('First');
      final firstId = notifier.state!.id;
      notifier.show('Second');

      expect(notifier.state!.id, isNot(firstId));
      expect(notifier.state!.message, 'Second');
    });
  });
}
