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

// Polling
const Duration kOrderPollInterval = Duration(seconds: 3);
const int kOrderPollMaxAttempts = 40; // 2 minutes

// Secure storage keys
const String kTokenKey = 'jwt_token';
const String kRoleKey = 'user_role';

// Shared-prefs keys
const String kLocaleKey = 'selected_locale';
