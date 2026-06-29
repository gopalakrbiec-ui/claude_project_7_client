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

  String? get token     => _prefs.getString(kTokenKey);
  String? get role      => _prefs.getString(kRoleKey);
  String? get firstName => _prefs.getString('profile_first_name');
  String? get lastName  => _prefs.getString('profile_last_name');
  String? get email     => _prefs.getString('profile_email');
  String? get city      => _prefs.getString('profile_city');
  String? get country   => _prefs.getString('profile_country');
  String? get state     => _prefs.getString('profile_state');

  // -- Async writes ---------------------------------------------------------

  Future<void> writeToken(String value) => _prefs.setString(kTokenKey, value);
  Future<void> writeRole(String value)  => _prefs.setString(kRoleKey, value);

  Future<void> writeProfile({
    required String firstName,
    required String lastName,
    String? email,
    required String city,
    required String country,
    String? state,
  }) async {
    await _prefs.setString('profile_first_name', firstName);
    await _prefs.setString('profile_last_name', lastName);
    await _prefs.setString('profile_city', city);
    await _prefs.setString('profile_country', country);
    if (email != null && email.isNotEmpty) {
      await _prefs.setString('profile_email', email);
    }
    if (state != null && state.isNotEmpty) {
      await _prefs.setString('profile_state', state);
    }
  }

  Future<void> clear() async {
    await _prefs.remove(kTokenKey);
    await _prefs.remove(kRoleKey);
    await _prefs.remove('profile_first_name');
    await _prefs.remove('profile_last_name');
    await _prefs.remove('profile_email');
    await _prefs.remove('profile_city');
    await _prefs.remove('profile_country');
    await _prefs.remove('profile_state');
  }
}
