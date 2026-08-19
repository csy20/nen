import 'package:flutter_test/flutter_test.dart';
import 'package:nen/data/repositories/settings_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('has_seen_onboarding defaults to false and persists', () async {
    final repo = SettingsRepositoryImpl();

    expect(await repo.getHasSeenOnboarding(), isFalse);

    await repo.setHasSeenOnboarding(true);
    expect(await repo.getHasSeenOnboarding(), isTrue);

    await repo.setHasSeenOnboarding(false);
    expect(await repo.getHasSeenOnboarding(), isFalse);
  });

  test('has_seen_onboarding does not clobber other settings keys', () async {
    final repo = SettingsRepositoryImpl();
    await repo.setReduceMotion(true);
    await repo.setThemeMode(1);

    await repo.setHasSeenOnboarding(true);

    expect(await repo.getReduceMotion(), isTrue);
    expect(await repo.getThemeMode(), 1);
    expect(await repo.getHasSeenOnboarding(), isTrue);
  });
}
