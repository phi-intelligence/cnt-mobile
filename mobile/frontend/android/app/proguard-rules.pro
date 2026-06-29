# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# LiveKit
-keep class livekit.** { *; }
-keep class org.webrtc.** { *; }

# Audio/Video players
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }

# Gson (used by some plugins)
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.** { *; }

# Keep model classes (prevent obfuscation of JSON serialization)
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# HTTP/Networking
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Prevent stripping of native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable implementations
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ============================================
# Google Play Core - Deferred Components (not used, suppress warnings)
# ============================================
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-keep class com.google.android.play.core.** { *; }

# ============================================
# Stripe Push Provisioning (optional feature - not used)
# ============================================
-dontwarn com.stripe.android.pushProvisioning.**
-keep class com.stripe.android.pushProvisioning.** { *; }

# React Native Stripe SDK (optional - ignore if missing)
-dontwarn com.reactnativestripesdk.**
-keep class com.reactnativestripesdk.** { *; }

# ============================================
# Stripe SDK - Keep necessary classes
# ============================================
-keep class com.stripe.android.** { *; }
-dontwarn com.stripe.android.**

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# App security / networking
-keep class com.christtabernacle.cntmedia.MainActivity { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

