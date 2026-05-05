plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Google services plugin for Firebase
    id("com.google.gms.google-services")
    // Firebase Crashlytics Gradle plugin
    id("com.google.firebase.crashlytics")
}

import java.util.Properties
import java.io.FileInputStream

// Cargar credenciales del release keystore desde key.properties (gitignored).
// Si el archivo no existe (entornos de CI sin secretos), el build release
// caer\u00e1 al keystore debug, pero advertimos en consola.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else {
    println("\u26a0\ufe0f  android/key.properties no encontrado: el build release usar\u00e1 la debug keystore.")
}

android {
    namespace = "com.example.app_quitar"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // applicationId definitivo (Play Store + Firebase Android app dedicada).
        // El namespace Kotlin sigue siendo com.example.app_quitar para
        // evitar refactor masivo; eso es cosmético, Android usa applicationId.
        applicationId = "com.victoriaencristo.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Required for Google Sign-In
        multiDexEnabled = true
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Firmar con keystore release real si existe, fallback a debug
            // s\u00f3lo en entornos sin secretos (CI sin claves provisionadas).
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8 + shrinker para reducir reversibilidad y tama\u00f1o.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
