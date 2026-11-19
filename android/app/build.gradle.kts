import java.util.Properties
import java.io.FileInputStream
import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = listOf(
    rootProject.file("key.properties"),
    file("key.properties"),
    file("../key.properties")
).firstOrNull { it.exists() }

if (keystorePropertiesFile != null) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.lhht.ai_assistant"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.king.hdvbot"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keyAliasVal = keystoreProperties.getProperty("keyAlias") ?: System.getenv("KEY_ALIAS")
            val keyPasswordVal = keystoreProperties.getProperty("keyPassword") ?: System.getenv("KEY_PASSWORD")
            val storeFileVal = keystoreProperties.getProperty("storeFile") ?: System.getenv("STORE_FILE")
            val storePasswordVal = keystoreProperties.getProperty("storePassword") ?: System.getenv("STORE_PASSWORD")
            val storeTypeVal = keystoreProperties.getProperty("storeType") ?: System.getenv("STORE_TYPE")

            val resolvedStoreFile = if (!storeFileVal.isNullOrEmpty()) {
                val candidates = listOf(
                    file(storeFileVal),
                    File(keystorePropertiesFile?.parentFile ?: project.projectDir, storeFileVal),
                    File(project.projectDir, storeFileVal),
                    rootProject.file(storeFileVal)
                )
                candidates.firstOrNull { it.exists() }
            } else null

            if (resolvedStoreFile != null && resolvedStoreFile.exists()) {
                storeFile = resolvedStoreFile
                storePassword = storePasswordVal
                keyAlias = keyAliasVal
                keyPassword = keyPasswordVal
                if (!storeTypeVal.isNullOrEmpty()) {
                    storeType = storeTypeVal
                }
            }
        }
    }

    buildTypes {
        release {
            val releaseSigning = signingConfigs.getByName("release")
            signingConfig = if (releaseSigning.storeFile != null) {
                releaseSigning
            } else {
                signingConfigs.getByName("debug")
            }
            // Enable R8 optimization
            isMinifyEnabled = true
            isDebuggable = false
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
            isDebuggable = true
        }
    }
}

flutter {
    source = "../.."
}

tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.15.0")
}
