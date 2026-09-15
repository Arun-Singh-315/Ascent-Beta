# Ascent ProGuard Rules
# Applied in release builds alongside proguard-android-optimize.txt

# ── Drift / SQLite ──────────────────────────────────────────────────────────
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

# ── flutter_local_notifications ─────────────────────────────────────────────
-keep class com.dexterous.** { *; }

# ── Keep Kotlin metadata for reflection (used by some plugins) ──────────────
-keep class kotlin.Metadata { *; }

# ── Keep Gson / JSON if used by any plugin ──────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*

# ── Suppress warnings for missing optional dependencies ─────────────────────
-dontwarn com.google.firebase.**
-dontwarn io.grpc.**
