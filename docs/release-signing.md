# Release Signing — Yaadein Android

## Overview

Signing credentials live **outside** source control.  The build reads them from
`android/key.properties` at compile time.  That file is git-ignored.

---

## One-time keystore generation (do this once, store the .jks securely)

```bash
keytool -genkey -v \
  -keystore secrets/yaadein-release.jks \
  -alias yaadein \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=Yaadein, OU=Engineering, O=Yaadein, L=Hyderabad, S=Telangana, C=IN"
```

> **Keep the .jks and both passwords in a password manager.**  
> If you lose the keystore you cannot update the app on Play Store — ever.

---

## Local developer setup

1. Generate or obtain the keystore file.
2. Create `android/key.properties` (git-ignored):

```properties
storeFile=../secrets/yaadein-release.jks
storePassword=<keystore-password>
keyAlias=yaadein
keyPassword=<key-password>
```

3. Never commit this file. The `.gitignore` blocks it.

---

## CI/CD setup (GitHub Actions)

Store four secrets in GitHub → Settings → Secrets and variables → Actions:

| Secret name | Value |
|---|---|
| `KEYSTORE_BASE64` | `base64 -i secrets/yaadein-release.jks` output |
| `KEYSTORE_PASSWORD` | The keystore password |
| `KEY_ALIAS` | `yaadein` |
| `KEY_PASSWORD` | The key password |

The release workflow (`.github/workflows/release.yml`) decodes the keystore and
writes `key.properties` at build time:

```yaml
- name: Decode keystore
  run: |
    echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 --decode \
      > android/secrets/yaadein-release.jks

- name: Write key.properties
  run: |
    cat > android/key.properties <<EOF
    storeFile=../secrets/yaadein-release.jks
    storePassword=${{ secrets.KEYSTORE_PASSWORD }}
    keyAlias=${{ secrets.KEY_ALIAS }}
    keyPassword=${{ secrets.KEY_PASSWORD }}
    EOF
```

---

## Build commands

### Play Store (recommended) — App Bundle (AAB)

```bash
flutter build appbundle \
  --release \
  --dart-define=API_BASE_URL=https://claudeproject7-production.up.railway.app \
  --obfuscate \
  --split-debug-info=build/debug-symbols/
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Play Store delivers a split APK to each user containing only their ABI
(arm64-v8a or armeabi-v7a).  No `splits` block needed in `build.gradle`.

### Direct APK distribution (outside Play Store)

```bash
flutter build apk \
  --release \
  --split-per-abi \
  --dart-define=API_BASE_URL=https://claudeproject7-production.up.railway.app \
  --obfuscate \
  --split-debug-info=build/debug-symbols/
```

Outputs three APKs:
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`   ← modern phones
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` ← older 32-bit phones
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`      ← emulators only

Without `--split-per-abi` you get a single fat APK ~45 MB larger than the per-ABI ones.

### Staging build (different backend URL)

```bash
flutter build appbundle \
  --release \
  --dart-define=API_BASE_URL=https://staging.example.com
```

No code change needed — `kApiBaseUrl` in `lib/core/constants.dart` reads from
`--dart-define` at compile time.

---

## `--obfuscate` and `--split-debug-info`

`--obfuscate` renames Dart symbols (not Java — R8 handles the Java side).
`--split-debug-info` writes a `.symbols` file needed to de-obfuscate crash
stack traces.  Upload this to Firebase Crashlytics or store it alongside each
release build.

---

## Stripping Dart debug info (already done by default in `--release`)

`flutter build --release` already runs Dart AOT with tree-shaking and no
debug metadata in the binary.  No extra flag needed.

---

## Disable LogInterceptor in release

`lib/api/dio_client.dart` has the `LogInterceptor` commented out.  Leave it
that way — it must never be uncommented in a production build because it
logs full request/response bodies including JWT tokens.

---

## Play Store upload checklist

- [ ] `versionCode` incremented in `pubspec.yaml` (the `+N` after the version)
- [ ] `versionName` updated (`major.minor.patch` before the `+`)
- [ ] AAB signed with the production keystore (same as all previous releases)
- [ ] `--split-debug-info` symbols file archived alongside the AAB
- [ ] Firebase Crashlytics mapping file (or `.symbols`) uploaded
- [ ] No hardcoded test credentials or debug flags
- [ ] `kApiBaseUrl` points to production (not staging)
- [ ] Release notes written for all three supported locales (en, hi, te)
- [ ] Content rating questionnaire up to date
- [ ] Privacy policy URL current
- [ ] Reviewed Play Store data safety section (OTP, UPI, location not collected)
