plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase Google Services plugin
    id("com.google.gms.google-services")
}

import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.christtabernacle.cntmedia"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        // Application ID for Christ New Tabernacle Media Platform
        applicationId = "com.christtabernacle.cntmedia"
        
        // minSdk 24 = Android 7.0+ for better compatibility with media features
        // LiveKit requires minimum SDK 21, but 24 gives us better camera/audio APIs
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Enable multidex for large app
        multiDexEnabled = true
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }

            // Enable code shrinking and resource optimization for production.
            // Use scripts/release_build.sh for --obfuscate and --split-debug-info.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
    
    // Split APKs by ABI to reduce download size
    splits {
        abi {
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86_64")
            isUniversalApk = true
        }
    }
}

// Exclude duplicate Media3 RTSP module to avoid class duplication
// Exclude duplicate WebRTC classes to avoid conflicts
configurations.all {
    exclude(group = "androidx.media3", module = "media3-exoplayer-rtsp")
}

flutter {
    source = "../.."
}

// Fail release builds only when assembling/bundling release — not during debug configuration.
gradle.taskGraph.whenReady {
    val isReleaseTask = gradle.startParameter.taskNames.any { task ->
        task.contains("Release", ignoreCase = true) &&
            (task.contains("assemble", ignoreCase = true) ||
                task.contains("bundle", ignoreCase = true) ||
                task.contains("install", ignoreCase = true))
    }
    if (isReleaseTask && !keystorePropertiesFile.exists()) {
        throw GradleException(
            "Release builds require android/key.properties with a release keystore. " +
                "Do not ship release APKs signed with the debug key."
        )
    }
}
