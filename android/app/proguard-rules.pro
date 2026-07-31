# ── Flutter default rules ─────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── flutter_secure_storage (Google Tink) ──────────────────
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.errorprone.annotations.**
-dontwarn com.google.errorprone.annotations.CanIgnoreReturnValue
-dontwarn com.google.errorprone.annotations.CheckReturnValue
-dontwarn com.google.errorprone.annotations.Immutable
-dontwarn com.google.errorprone.annotations.RestrictedApi
-dontwarn javax.annotation.**
-dontwarn javax.annotation.Nullable
-dontwarn javax.annotation.concurrent.GuardedBy

# ── Hive (local storage) ──────────────────────────────────
-keep class * extends io.flutter.plugin.common.MessageCodec { *; }
-keep class **.hive.** { *; }

# ── shared_preferences ────────────────────────────────────
-keep class androidx.preference.** { *; }

# ── Kotlin metadata ───────────────────────────────────────
-keep class kotlin.Metadata { *; }
-keep class kotlin.reflect.** { *; }

# ── Prevent obfuscation of app model classes ──────────────
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable

# ── Keep native methods ───────────────────────────────────
-keepclasseswithmembernames class * {
    native <methods>;
}

# ── Keep enum members ─────────────────────────────────────
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ── OkHttp / HTTP ─────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**