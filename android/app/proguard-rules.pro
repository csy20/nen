# ── Flutter ───────────────────────────────────────────────────────────
# Keep Flutter engine and plugin registrant
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# App MethodChannel / EventChannel plugins (visualizer, MainActivity)
-keep class dev.csy20.nen.** { *; }

# ── audio_service ────────────────────────────────────────────────────
-keep class com.ryanheise.audioservice.** { *; }

# ── flutter_soloud (native audio engine) ─────────────────────────────
-keep class com.atsumeru.flutter_soloud.** { *; }

# ── on_audio_query ───────────────────────────────────────────────────
-keep class com.lucasjosino.on_audio_query.** { *; }

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
