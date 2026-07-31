# ══════════════════════════════════════════════════════════
# FLUTTER CORE RULES
# ══════════════════════════════════════════════════════════
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# ══════════════════════════════════════════════════════════
# GOOGLE PLAY CORE — Deferred Components (NOT USED)
# Flutter references but we don't use them
# ══════════════════════════════════════════════════════════
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# ══════════════════════════════════════════════════════════
# FLUTTER_SECURE_STORAGE + GOOGLE TINK CRYPTO
# ══════════════════════════════════════════════════════════
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# Error-prone annotations
-dontwarn com.google.errorprone.annotations.**
-dontwarn com.google.errorprone.annotations.CanIgnoreReturnValue
-dontwarn com.google.errorprone.annotations.CheckReturnValue
-dontwarn com.google.errorprone.annotations.Immutable
-dontwarn com.google.errorprone.annotations.RestrictedApi

# JSR-305 annotations
-dontwarn javax.annotation.**
-dontwarn javax.annotation.Nullable
-dontwarn javax.annotation.concurrent.GuardedBy

# ══════════════════════════════════════════════════════════
# GOOGLE API CLIENT — Tink HTTP downloader (NOT USED)
# ══════════════════════════════════════════════════════════
-dontwarn com.google.api.client.**
-dontwarn com.google.api.client.http.**
-dontwarn com.google.api.client.http.javanet.**

# ══════════════════════════════════════════════════════════
# JODA TIME — Optional Tink dependency (NOT USED)
# ══════════════════════════════════════════════════════════
-dontwarn org.joda.time.**
-dontwarn org.joda.time.Instant

# ══════════════════════════════════════════════════════════
# HIVE (local storage)
# ══════════════════════════════════════════════════════════
-keep class * extends io.flutter.plugin.common.MessageCodec { *; }
-keep class **.hive.** { *; }

# ══════════════════════════════════════════════════════════
# SHARED PREFERENCES
# ══════════════════════════════════════════════════════════
-keep class androidx.preference.** { *; }

# ══════════════════════════════════════════════════════════
# KOTLIN METADATA
# ══════════════════════════════════════════════════════════
-keep class kotlin.Metadata { *; }
-keep class kotlin.reflect.** { *; }
-dontwarn kotlin.**

# ══════════════════════════════════════════════════════════
# PRESERVE ANNOTATIONS AND SIGNATURES
# ══════════════════════════════════════════════════════════
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# ══════════════════════════════════════════════════════════
# KEEP NATIVE METHODS
# ══════════════════════════════════════════════════════════
-keepclasseswithmembernames class * {
    native <methods>;
}

# ══════════════════════════════════════════════════════════
# KEEP ENUM MEMBERS
# ══════════════════════════════════════════════════════════
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ══════════════════════════════════════════════════════════
# OKHTTP / OKIO / NETWORKING
# ══════════════════════════════════════════════════════════
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# ══════════════════════════════════════════════════════════
# CONNECTIVITY PLUS
# ══════════════════════════════════════════════════════════
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# ══════════════════════════════════════════════════════════
# FLUTTER LOCAL NOTIFICATIONS
# ══════════════════════════════════════════════════════════
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# ══════════════════════════════════════════════════════════
# SUPPRESS ALL WARNINGS FOR CLEAN BUILD
# ══════════════════════════════════════════════════════════
-ignorewarnings