plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase Google Services plugin
    id("com.google.gms.google-services")
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
            // For production release, you should create a keystore and configure signing:
            // 1. Generate keystore: keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
            // 2. Create key.properties file with storePassword, keyPassword, keyAlias, storeFile
            // 3. Configure signingConfigs.create("release") with the keystore
            // For now, using debug signing for testing
            signingConfig = signingConfigs.getByName("debug")
            
            // Enable code shrinking and resource optimization for production
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        
        debug {
            // Debug build settings
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
