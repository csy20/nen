# ── Flutter ───────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class * implements io.flutter.embedding.engine.plugins.activity.ActivityAware { *; }

# App plugins
-keep class dev.csy20.nen.** { *; }

# ── audio_service ────────────────────────────────────────────────────
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.audioservice.AudioService { *; }
-keep class com.ryanheise.audioservice.MediaButtonReceiver { *; }

# ── just_audio / ExoPlayer / Media3 ──────────────────────────────────
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }
-keep class androidx.media.** { *; }
-keep class android.support.v4.media.** { *; }

# ── on_audio_query ───────────────────────────────────────────────────
-keep class com.lucasjosino.on_audio_query.** { *; }
-keepclassmembers class com.lucasjosino.on_audio_query.PluginProvider {
    *;
}
-keep class kotlin.UninitializedPropertyAccessException { *; }

# ── in_app_review ────────────────────────────────────────────────────
-keep class com.google.android.play.core.review.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# ── General Android ──────────────────────────────────────────────────
-keep class androidx.lifecycle.** { *; }
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes Exceptions

-dontwarn com.google.**
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
-dontwarn javax.annotation.**
