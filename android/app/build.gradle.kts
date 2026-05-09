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
// Si el archivo no existe Y se está construyendo un release (assembleRelease,
// bundleRelease), abortamos: una APK release firmada con la debug key no
// puede subirse a Play Store y se considera un downgrade de seguridad.
// Para builds debug/CI sin keystore release, se permite el fallback.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else {
    val isReleaseBuild = gradle.startParameter.taskNames.any {
        it.contains("Release", ignoreCase = true) ||
        it.contains("bundle", ignoreCase = true) && it.contains("release", ignoreCase = true)
    }
    val allowDebugSigningInRelease = (project.findProperty("ALLOW_DEBUG_SIGNING_IN_RELEASE") as String?) == "true"
    if (isReleaseBuild && !allowDebugSigningInRelease) {
        throw GradleException(
            "android/key.properties no encontrado y se está construyendo un release.\n" +
            "  - Para builds locales debug usa `flutter build apk --debug`.\n" +
            "  - Para release real, copia la keystore a key.properties.\n" +
            "  - Si realmente quieres firmar release con debug (NO recomendado), pasa\n" +
            "    -PALLOW_DEBUG_SIGNING_IN_RELEASE=true en el comando gradle."
        )
    }
    println("⚠️  android/key.properties no encontrado: build no-release usará debug keystore.")
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
