import '../logging/secure_logger.dart';
import '../storage/database.dart';
import 'key_store.dart';

/// DB key rekey policy.
///
/// The key rotates every 90 days. The check runs at app start and on
/// resume. Rekey is cheap for a small queue but not free — do not run
/// it on every open.
class RekeyPolicy {
  RekeyPolicy._();

  static const interval = Duration(days: 90);

  /// Returns true when a rekey is due. Does not perform the rekey.
  static Future<bool> isDue() async {
    final last = await KeyStore.getLastRekeyAt();
    if (last == null) {
      await KeyStore.setLastRekeyAt(DateTime.now().toUtc());
      return false;
    }
    final age = DateTime.now().toUtc().difference(last);
    return age >= interval;
  }

  /// Runs a rekey if one is due. Returns true if a rekey happened.
  static Future<bool> runIfDue() async {
    if (!await isDue()) return false;
    try {
      await AppDatabase.rekey();
      return true;
    } catch (e) {
      SecureLogger.e('rekey.failed', error: e);
      return false;
    }
  }
}
