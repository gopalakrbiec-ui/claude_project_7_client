import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

// ---------------------------------------------------------------------------
// TokenStorage — synchronous reads, async writes.
//
// Uses SharedPreferences instead of flutter_secure_storage so that reads
// never touch the Android hardware Keystore. The Keystore can deadlock the
// platform channel after a device reboot or screen lock, causing an infinite
// spinner that no Future.timeout() can rescue.
//
// SharedPreferences is initialised once in main() and injected via
// ProviderScope.overrides. All reads are O(1) in-memory; writes flush to
// disk asynchronously.
// ---------------------------------------------------------------------------

// Provided by main() override after awaiting SharedPreferences.getInstance().
final tokenStorageProvider = Provider<TokenStorage>(
  (_) => throw UnimplementedError('tokenStorageProvider not initialised'),
);

class TokenStorage {
  TokenStorage(this._prefs);
  final SharedPreferences _prefs;

  // -- Synchronous reads (safe to call anywhere, no await) ------------------

  String? get token => _prefs.getString(kTokenKey);
  String? get role  => _prefs.getString(kRoleKey);

  // -- Async writes ---------------------------------------------------------

  Future<void> writeToken(String value) => _prefs.setString(kTokenKey, value);
  Future<void> writeRole(String value)  => _prefs.setString(kRoleKey, value);

  Future<void> clear() async {
    await _prefs.remove(kTokenKey);
    await _prefs.remove(kRoleKey);
  }
}
