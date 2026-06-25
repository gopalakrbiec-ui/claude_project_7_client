import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:life_event_editor/controllers/auth_controller.dart';
import 'package:life_event_editor/models/user_profile.dart';

UserProfile _profile({required String role, String name = 'Test'}) {
  return UserProfile(
    id: 'u1',
    phone: '+919876543210',
    role: role,
    name: name,
  );
}

/// Override [authControllerProvider] with a static value for testing.
ProviderContainer _containerWithAuth(AuthState state) {
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(() => _StaticAuthController(state)),
    ],
  );
}

class _StaticAuthController extends AuthController {
  _StaticAuthController(this._fixedState);
  final AuthState _fixedState;

  @override
  AuthState build() => _fixedState;
}

void main() {
  group('isAgentProvider', () {
    test('returns true when profile role is "agent"', () {
      final container = _containerWithAuth(
        AuthAuthenticated(profile: _profile(role: 'agent')),
      );
      addTearDown(container.dispose);

      expect(container.read(isAgentProvider), isTrue);
    });

    test('returns false when profile role is "consumer"', () {
      final container = _containerWithAuth(
        AuthAuthenticated(profile: _profile(role: 'consumer')),
      );
      addTearDown(container.dispose);

      expect(container.read(isAgentProvider), isFalse);
    });

    test('returns false when unauthenticated', () {
      final container = _containerWithAuth(const AuthUnauthenticated());
      addTearDown(container.dispose);

      expect(container.read(isAgentProvider), isFalse);
    });

    test('returns false when initializing', () {
      final container = _containerWithAuth(const AuthInitializing());
      addTearDown(container.dispose);

      expect(container.read(isAgentProvider), isFalse);
    });

    test('updates reactively when auth state changes', () {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider
              .overrideWith(() => _MutableAuthController()),
        ],
      );
      addTearDown(container.dispose);

      // Initially consumer
      expect(container.read(isAgentProvider), isFalse);

      // Simulate role change to agent (e.g. after /auth/me refresh)
      (container.read(authControllerProvider.notifier) as _MutableAuthController)
          .setProfile(_profile(role: 'agent'));

      expect(container.read(isAgentProvider), isTrue);

      // Back to consumer
      (container.read(authControllerProvider.notifier) as _MutableAuthController)
          .setProfile(_profile(role: 'consumer'));

      expect(container.read(isAgentProvider), isFalse);
    });
  });

  group('isAgent on UserProfile', () {
    test('isAgent is true for role "agent"', () {
      expect(_profile(role: 'agent').isAgent, isTrue);
    });

    test('isAgent is false for role "consumer"', () {
      expect(_profile(role: 'consumer').isAgent, isFalse);
    });

    test('isAgent is false for any unknown role string', () {
      expect(_profile(role: 'superadmin').isAgent, isFalse);
      expect(_profile(role: '').isAgent, isFalse);
    });
  });
}

// ---------------------------------------------------------------------------
// Mutable test controller that supports mid-test state changes.
// ---------------------------------------------------------------------------
class _MutableAuthController extends AuthController {
  @override
  AuthState build() => AuthAuthenticated(profile: _profile(role: 'consumer'));

  void setProfile(UserProfile profile) {
    state = AuthAuthenticated(profile: profile);
  }
}
