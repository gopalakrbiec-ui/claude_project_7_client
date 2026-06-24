const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://claudeproject7-production.up.railway.app',
);

// Minimum touch target per Material / WCAG (48×48 logical pixels)
const double kMinTapTarget = 48.0;

// Spacing scale
const double kSpaceXs = 4.0;
const double kSpaceSm = 8.0;
const double kSpaceMd = 16.0;
const double kSpaceLg = 24.0;
const double kSpaceXl = 32.0;

// Network
const Duration kConnectTimeout = Duration(seconds: 10);
const Duration kReceiveTimeout = Duration(seconds: 30);

// Order-status polling — exponential backoff
// Sequence: 3s → 4.5s → 6.75s → 10.1s → 15.2s → 22.8s → 30s (cap)
// Covers the 30–120 s typical AI generation window cheaply, then slows to
// 30 s intervals.  Total with 40 attempts ≈ 18 minutes before timeout.
const Duration kOrderPollInitialDelay = Duration(seconds: 3);
const Duration kOrderPollMaxDelay = Duration(seconds: 30);
const int kOrderPollMaxAttempts = 40;
// Legacy alias kept so TopupController test helpers compile.
const Duration kOrderPollInterval = kOrderPollInitialDelay;

// GET-only auto-retry (never applied to POST/PUT/DELETE)
// Backoff: 1 s → 2 s → 4 s, then give up and let the controller decide.
// Three attempts means at most 7 extra seconds on a flaky connection — acceptable
// for a slow rural network but not so long it feels broken.
const int kGetMaxRetries = 3;
const Duration kGetRetryBaseDelay = Duration(seconds: 1);

// Secure storage keys
const String kTokenKey = 'jwt_token';
const String kRoleKey = 'user_role';

// Shared-prefs keys
const String kLocaleKey = 'selected_locale';

// Template list in-memory cache
// After this duration the next navigation to home triggers a background refresh.
const Duration kTemplateCacheTtl = Duration(minutes: 5);

// Credit top-up: poll GET /credits/balance after Razorpay checkout closes.
// We do NOT trust the on-device success callback — the actual credit arrives
// via a server-side webhook. Poll until balance rises or we time out.
const Duration kTopupPollInterval = Duration(seconds: 3);
const int kTopupPollMaxAttempts = 20; // 60 seconds total
