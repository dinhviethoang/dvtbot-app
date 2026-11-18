plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.lhht.ai_assistant"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.king.hdvbot"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("hdvbot") {
            // Khoa ky co dinh de cac ban build sau cai de len ban cu duoc (repo rieng tu)
            storeFile = file("hdvbot-release.p12")
            storeType = "pkcs12"
            storePassword = "46a1905cec90c7242ea68634"
            keyAlias = "hdvbot"
            keyPassword = "46a1905cec90c7242ea68634"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("hdvbot")
            // 启用R8优化
            isMinifyEnabled = true
            isDebuggable = false
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        
        debug {
            // 启用更好的调试性能
            isMinifyEnabled = false
            isShrinkResources = false
            isDebuggable = true
        }
    }
}

flutter {
    source = "../.."
}
