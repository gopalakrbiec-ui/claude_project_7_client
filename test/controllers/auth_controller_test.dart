import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:life_event_editor/api/api_error.dart';
import 'package:life_event_editor/controllers/auth_controller.dart';
import 'package:life_event_editor/core/token_storage.dart';
import 'package:life_event_editor/models/user_profile.dart';
import 'package:life_event_editor/models/verify_otp_result.dart';
import 'package:life_event_editor/repositories/auth_repository.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------
class MockAuthRepository extends Mock implements AuthRepository {}
class MockTokenStorage extends Mock implements TokenStorage {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
const _kToken = 'test-jwt-token';
const _kPhone = '+919876543210';
const _kCode  = '123456';

final _fakeProfile = UserProfile(
  id: 'user-1',
  phone: _kPhone,
  role: 'user',
  name: 'Test User',
  preferredLanguage: 'en',
);

MockTokenStorage _makeStorage({String? token, String? role}) {
  final s = MockTokenStorage();
  when(() => s.token).thenReturn(token);
  when(() => s.role).thenReturn(role);
  when(() => s.writeToken(any())).thenAnswer((_) async {});
  when(() => s.writeRole(any())).thenAnswer((_) async {});
  when(() => s.clear()).thenAnswer((_) async {});
  return s;
}

ProviderContainer _makeContainer({
  required MockAuthRepository repo,
  required MockTokenStorage storage,
}) {
  final c = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// Pumps the event loop until the auth controller is no longer initializing.
Future<void> _settle(ProviderContainer c) => _settleUntil(c, (s) => s is! AuthInitializing);

/// Pumps the event loop until [pred] returns true or 100 iterations pass.
Future<void> _settleUntil(ProviderContainer c, bool Function(AuthState) pred) async {
  await Future<void>.delayed(Duration.zero);
  for (int i = 0; i < 100; i++) {
    if (pred(c.read(authControllerProvider))) return;
    await Future<void>.delayed(Duration.zero);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
void main() {
  late MockAuthRepository repo;

  setUp(() {
    repo = MockAuthRepository();
  });

  group('Initialisation', () {
    test('→ AuthUnauthenticated when no token is stored', () async {
      final storage = _makeStorage();
      final c = _makeContainer(repo: repo, storage: storage);

      expect(c.read(authControllerProvider), isA<AuthInitializing>());
      await _settle(c);

      expect(c.read(authControllerProvider), isA<AuthUnauthenticated>());
      verifyNever(() => repo.getMe());
    });

    test('→ AuthAuthenticated when token valid + /auth/me succeeds', () async {
      final storage = _makeStorage(token: _kToken);
      when(() => repo.getMe()).thenAnswer((_) async => _fakeProfile);

      final c = _makeContainer(repo: repo, storage: storage);
      // Optimistic restore fires first (empty profile), then getMe() updates it.
      await _settleUntil(c, (s) =>
          s is AuthAuthenticated && s.profile.id == 'user-1');

      final state = c.read(authControllerProvider);
      expect(state, isA<AuthAuthenticated>());
      final auth = state as AuthAuthenticated;
      expect(auth.profile.phone, _kPhone);
      expect(auth.profile.role, 'user');
      expect(auth.isNewUser, false);
      verify(() => storage.writeRole('user')).called(1);
    });

    test('→ AuthUnauthenticated + credentials cleared on 401 from /auth/me',
        () async {
      final storage = _makeStorage(token: _kToken);
      when(() => repo.getMe())
          .thenThrow(const ServerError(statusCode: 401, message: 'Unauthorized'));

      final c = _makeContainer(repo: repo, storage: storage);
      // Optimistic restore sets AuthAuthenticated first; 401 then clears it.
      await _settleUntil(c, (s) => s is AuthUnauthenticated);

      expect(c.read(authControllerProvider), isA<AuthUnauthenticated>());
      verify(() => storage.clear()).called(1);
    });

    test('→ AuthAuthenticated with cached role on non-401 /auth/me error',
        () async {
      final storage = _makeStorage(token: _kToken, role: 'agent');
      when(() => repo.getMe()).thenThrow(const NetworkError(message: 'timeout'));

      final c = _makeContainer(repo: repo, storage: storage);
      // Optimistic restore uses cached role immediately; network error keeps it.
      await _settle(c);
      // Drain background getMe() error so it doesn't bleed into next test.
      await _settleUntil(c, (_) => true);

      final state = c.read(authControllerProvider);
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).profile.role, 'agent');
    });
  });

  group('requestOtp', () {
    test('delegates to repository and returns without state change', () async {
      final storage = _makeStorage();
      when(() => repo.requestOtp(_kPhone)).thenAnswer((_) async {});

      final c = _makeContainer(repo: repo, storage: storage);
      await _settle(c);

      await c.read(authControllerProvider.notifier).requestOtp(_kPhone);

      verify(() => repo.requestOtp(_kPhone)).called(1);
      expect(c.read(authControllerProvider), isA<AuthUnauthenticated>());
    });

    test('re-throws ApiError on network failure', () async {
      final storage = _makeStorage();
      when(() => repo.requestOtp(_kPhone))
          .thenThrow(const NetworkError(message: 'offline'));

      final c = _makeContainer(repo: repo, storage: storage);
      await _settle(c);

      await expectLater(
        () => c.read(authControllerProvider.notifier).requestOtp(_kPhone),
        throwsA(isA<NetworkError>()),
      );
    });
  });

  group('verifyOtp', () {
    test('→ AuthAuthenticated on success; token + role persisted', () async {
      final storage = _makeStorage();
      when(() => repo.verifyOtp(_kPhone, _kCode)).thenAnswer(
        (_) async => const VerifyOtpResult(
          accessToken: _kToken,
          tokenType: 'bearer',
          role: 'user',
          isNewUser: true,
        ),
      );

      final c = _makeContainer(repo: repo, storage: storage);
      await _settle(c);

      await c.read(authControllerProvider.notifier).verifyOtp(_kPhone, _kCode);

      final state = c.read(authControllerProvider);
      expect(state, isA<AuthAuthenticated>());
      final auth = state as AuthAuthenticated;
      expect(auth.profile.phone, _kPhone);
      expect(auth.profile.role, 'user');
      expect(auth.isNewUser, true);
      verify(() => storage.writeToken(_kToken)).called(1);
      verify(() => storage.writeRole('user')).called(1);
    });

    test('→ AuthAuthenticated with agent role for agent accounts', () async {
      final storage = _makeStorage();
      when(() => repo.verifyOtp(_kPhone, _kCode)).thenAnswer(
        (_) async => const VerifyOtpResult(
          accessToken: _kToken,
          tokenType: 'bearer',
          role: 'agent',
          isNewUser: false,
        ),
      );

      final c = _makeContainer(repo: repo, storage: storage);
      await _settle(c);

      await c.read(authControllerProvider.notifier).verifyOtp(_kPhone, _kCode);

      final state = c.read(authControllerProvider) as AuthAuthenticated;
      expect(state.profile.isAgent, true);
    });

    test('re-throws ServerError(400) on wrong OTP; state stays unauthenticated',
        () async {
      final storage = _makeStorage();
      when(() => repo.verifyOtp(_kPhone, _kCode))
          .thenThrow(const ServerError(statusCode: 400, message: 'Wrong OTP'));

      final c = _makeContainer(repo: repo, storage: storage);
      await _settle(c);

      await expectLater(
        () => c.read(authControllerProvider.notifier).verifyOtp(_kPhone, _kCode),
        throwsA(isA<ServerError>()),
      );
      expect(c.read(authControllerProvider), isA<AuthUnauthenticated>());
    });

    test('re-throws ServerError(401) on expired OTP', () async {
      final storage = _makeStorage();
      when(() => repo.verifyOtp(_kPhone, _kCode))
          .thenThrow(const ServerError(statusCode: 401, message: 'OTP expired'));

      final c = _makeContainer(repo: repo, storage: storage);
      await _settle(c);

      await expectLater(
        () => c.read(authControllerProvider.notifier).verifyOtp(_kPhone, _kCode),
        throwsA(isA<ServerError>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('re-throws ServerError(429) on too many attempts', () async {
      final storage = _makeStorage();
      when(() => repo.verifyOtp(_kPhone, _kCode)).thenThrow(
          const ServerError(statusCode: 429, message: 'Too many attempts'));

      final c = _makeContainer(repo: repo, storage: storage);
      await _settle(c);

      await expectLater(
        () => c.read(authControllerProvider.notifier).verifyOtp(_kPhone, _kCode),
        throwsA(isA<ServerError>().having((e) => e.statusCode, 'statusCode', 429)),
      );
    });

    test('re-throws NetworkError on connectivity failure', () async {
      final storage = _makeStorage();
      when(() => repo.verifyOtp(_kPhone, _kCode))
          .thenThrow(const NetworkError());

      final c = _makeContainer(repo: repo, storage: storage);
      await _settle(c);

      await expectLater(
        () => c.read(authControllerProvider.notifier).verifyOtp(_kPhone, _kCode),
        throwsA(isA<NetworkError>()),
      );
    });
  });

  group('logout', () {
    test('→ AuthUnauthenticated; clears credentials', () async {
      final storage = _makeStorage(token: _kToken);
      when(() => repo.getMe()).thenAnswer((_) async => _fakeProfile);

      final c = _makeContainer(repo: repo, storage: storage);
      await _settle(c);
      expect(c.read(authControllerProvider), isA<AuthAuthenticated>());

      await c.read(authControllerProvider.notifier).logout();

      expect(c.read(authControllerProvider), isA<AuthUnauthenticated>());
      verify(() => storage.clear()).called(1);
    });
  });

  group('forceLogout', () {
    test('→ AuthUnauthenticated synchronously (called by JWT interceptor)',
        () async {
      final storage = _makeStorage(token: _kToken);
      when(() => repo.getMe()).thenAnswer((_) async => _fakeProfile);

      final c = _makeContainer(repo: repo, storage: storage);
      await _settle(c);
      expect(c.read(authControllerProvider), isA<AuthAuthenticated>());

      c.read(authControllerProvider.notifier).forceLogout();

      expect(c.read(authControllerProvider), isA<AuthUnauthenticated>());
    });
  });
}
