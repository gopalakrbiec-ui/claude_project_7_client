# =============================================================================
# Yaadein — Production ProGuard / R8 rules
#
# Rule of thumb: keep the minimum necessary.  Over-broad -keep rules defeat
# the purpose of R8 full mode.  Each block below explains WHY it's needed.
# =============================================================================

# ── Flutter engine ────────────────────────────────────────────────────────────
# The Flutter embedding uses reflection to load plugin registrars.
# Without these rules R8 strips the registrar lookup table.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ── Razorpay ─────────────────────────────────────────────────────────────────
# Razorpay's SDK is distributed as an AAR and uses runtime class loading for
# its payment-method fragments and the UPI intent resolution table.
# Without these rules the checkout UI fails to open silently in release.
-keep class com.razorpay.** { *; }
-keep interface com.razorpay.** { *; }
-dontwarn com.razorpay.**
# Razorpay bundles OkHttp — keep enough to avoid NoSuchMethodError at runtime.
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }
# ProGuard optimisation that Razorpay's documentation says must be disabled:
# inlining across method boundaries can break the Razorpay payment fragment.
-optimizations !method/inlining/*

# ── flutter_secure_storage ────────────────────────────────────────────────────
# Uses Android KeyStore APIs via reflection; class names must survive shrinking.
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# ── flutter_image_compress ────────────────────────────────────────────────────
# JNI bridge to libjpeg-turbo native library; the Java wrapper class name must
# match what the .so looks up at runtime via System.loadLibrary.
-keep class com.fluttercandies.imagecompress.** { *; }
-dontwarn com.fluttercandies.**

# ── image_picker ──────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.imagepicker.** { *; }
-dontwarn io.flutter.plugins.imagepicker.**

# ── share_plus ────────────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.share.** { *; }
-dontwarn dev.fluttercommunity.plus.share.**

# ── gal (gallery saver) ───────────────────────────────────────────────────────
-keep class com.natsuk2003.gal.** { *; }
-dontwarn com.natsuk2003.gal.**

# ── path_provider ─────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.pathprovider.** { *; }

# ── connectivity_plus ─────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
-dontwarn dev.fluttercommunity.plus.connectivity.**

# ── Dio / Dart HTTP stack ─────────────────────────────────────────────────────
# Dio is pure Dart compiled to native ARM — no Java reflection, no keep rules
# needed.  The only Java side is the HTTP engine used internally by the Dart VM
# which is packaged inside the Flutter engine AAR (already kept above).

# ── Freezed / json_serializable ───────────────────────────────────────────────
# These are Dart code-generation tools.  The generated code is pure Dart AOT —
# no Java annotations, no reflection.  No ProGuard rules needed.

# ── Kotlin coroutines (used by several plugins) ───────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-dontwarn kotlinx.coroutines.**

# ── Annotation retention ──────────────────────────────────────────────────────
# Some SDKs use annotations at runtime (e.g. Razorpay's Jackson/Gson wrappers).
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# ── General Android safety rules ─────────────────────────────────────────────
# Keep Parcelable implementations — used by Android's IPC layer.
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}
# Keep enum values — some plugins enumerate these at runtime.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
# Keep serializable classes (used by Bundle extras).
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
