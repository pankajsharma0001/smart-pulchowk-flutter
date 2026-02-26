# ── Flutter Local Notifications ──────────────────────────────────────
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# ── Firebase Cloud Messaging ─────────────────────────────────────────
-keep class io.flutter.plugins.firebase.messaging.** { *; }
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }

# ── Google Play Services ─────────────────────────────────────────────
-keep class com.google.android.gms.** { *; }

# ── Gson / Serialization ─────────────────────────────────────────────
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod

# ── AndroidX ────────────────────────────────────────────────────────
-keep class androidx.work.** { *; }
-keep class androidx.lifecycle.** { *; }

# ── General safety ──────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Application Package (Smart Pulchowk) ─────────────────────────────
# Keep EVERYTHING in the main package to prevent any obfuscation issues 
# with background isolates or model serialization.
-keep class com.pankajsharma.smart_pulchowk.** { *; }

# ── Google Play Core ────────────────────────────────────────────────
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.appupdate.**
-dontwarn com.google.android.play.core.review.**

# ── Useful for debugging ─────────────────────────────────────────────
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
