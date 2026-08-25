# ── Flutter ───────────────────────────────────────────────────────────
# Keep Flutter engine and plugin registrant
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class * implements io.flutter.embedding.engine.plugins.activity.ActivityAware { *; }

# App MethodChannel / EventChannel plugins (visualizer, MainActivity, library)
-keep class dev.csy20.nen.** { *; }
-keep class dev.csy20.nen.LibraryMediaStorePlugin { *; }

# ── audio_service ────────────────────────────────────────────────────
-keep class com.ryanheise.audioservice.** { *; }

# ── flutter_soloud (native audio engine) ─────────────────────────────
-keep class com.atsumeru.flutter_soloud.** { *; }

# ── on_audio_query ───────────────────────────────────────────────────
-keep class com.lucasjosino.on_audio_query.** { *; }
-keepclassmembers class com.lucasjosino.on_audio_query.PluginProvider {
    *;
}
-keep class kotlin.UninitializedPropertyAccessException { *; }

# ── in_app_review (Play In-App Review API) ───────────────────────────
-keep class com.google.android.play.core.review.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# ── General Android ──────────────────────────────────────────────────
-keep class androidx.lifecycle.** { *; }

# Don't warn about missing classes from optional dependencies
-dontwarn com.google.**
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
-dontwarn javax.annotation.**
