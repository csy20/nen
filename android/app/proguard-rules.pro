# ── Flutter ───────────────────────────────────────────────────────────
# Keep Flutter engine and plugin registrant
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── audio_service ────────────────────────────────────────────────────
-keep class com.ryanheise.audioservice.** { *; }

# ── flutter_soloud (native audio engine) ─────────────────────────────
-keep class com.atsumeru.flutter_soloud.** { *; }

# ── on_audio_query ───────────────────────────────────────────────────
-keep class com.lucasjosino.on_audio_query.** { *; }

# ── General Android ──────────────────────────────────────────────────
-keep class androidx.lifecycle.** { *; }

# Don't warn about missing classes from optional dependencies
-dontwarn com.google.**
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
-dontwarn javax.annotation.**
