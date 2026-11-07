import 'package:integration_test/integration_test_driver.dart';

/// Attach to a verified, already installed test build using VM_SERVICE_URL.
/// All test records and preferences live in memory; this driver never installs,
/// uninstalls, or clears the app on the user's phone.
Future<void> main() => integrationDriver(responseDataCallback: (_) async {});
