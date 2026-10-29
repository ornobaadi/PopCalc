import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:popcalc/core/update/update_prompter.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppUpdateInfo _info({
  UpdateAvailability availability = UpdateAvailability.updateAvailable,
  InstallStatus status = InstallStatus.unknown,
}) => AppUpdateInfo(
  updateAvailability: availability,
  immediateUpdateAllowed: true,
  immediateAllowedPreconditions: null,
  flexibleUpdateAllowed: true,
  flexibleAllowedPreconditions: null,
  availableVersionCode: 17,
  installStatus: status,
  packageName: 'com.ornobaadi.popcalc',
  clientVersionStalenessDays: 1,
  updatePriority: 0,
);

void main() {
  late int started;
  late int installed;
  late DateTime clock;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    started = 0;
    installed = 0;
    clock = DateTime(2026, 11, 1);
    UpdatePrompter.enabled = true;
    UpdatePrompter.now = () => clock;
    UpdatePrompter.start = () async {
      started++;
      return AppUpdateResult.success;
    };
    UpdatePrompter.install = () async => installed++;
  });

  test('offers a newer version, then waits three days before asking again', () async {
    UpdatePrompter.check = () async => _info();
    await UpdatePrompter.run();
    expect(started, 1);
    clock = clock.add(const Duration(days: 1));
    await UpdatePrompter.run();
    expect(started, 1);
    clock = clock.add(const Duration(days: 3));
    await UpdatePrompter.run();
    expect(started, 2);
  });

  test('installs a download from last time at launch', () async {
    UpdatePrompter.check = () async => _info(status: InstallStatus.downloaded);
    await UpdatePrompter.run();
    expect([installed, started], [1, 0]);
  });

  test('says nothing when up to date or offline', () async {
    UpdatePrompter.check = () async =>
        _info(availability: UpdateAvailability.updateNotAvailable);
    await UpdatePrompter.run();
    UpdatePrompter.check = () async => throw Exception('offline');
    await UpdatePrompter.run();
    expect([installed, started], [0, 0]);
  });
}
