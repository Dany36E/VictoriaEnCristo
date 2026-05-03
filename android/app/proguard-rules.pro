# ─────────────────────────────────────────────────────────────────────
# ProGuard / R8 rules para Victoria en Cristo
# Aplicado en builds release con isMinifyEnabled = true.
# ─────────────────────────────────────────────────────────────────────

# Flutter / Dart engine
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase: Auth, Firestore, Functions, Messaging, Crashlytics, Analytics
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firestore reflection sobre POJOs (modelos serializables)
-keepclassmembers class * {
    @com.google.firebase.firestore.IgnoreExtraProperties *;
    @com.google.firebase.firestore.PropertyName *;
}

# Crashlytics: preservar nombres para stacktraces legibles
-keepattributes SourceFile,LineNumberTable
-keep class com.google.firebase.crashlytics.** { *; }

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# Just Audio / ExoPlayer
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# flutter_local_notifications
-keep class com.dexterous.** { *; }

# home_widget
-keep class es.antonborri.** { *; }

# Kotlin metadata
-keep class kotlin.Metadata { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

# Reflection-based JSON parsers (json_serializable / freezed)
-keepclassmembers,allowobfuscation class * {
    @com.fasterxml.jackson.annotation.* <methods>;
    @com.google.gson.annotations.* <fields>;
}

# Suprimir warnings de bibliotecas opcionales
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.*
