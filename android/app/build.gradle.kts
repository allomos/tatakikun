import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// The version is the Mac app's (App/Info.plist), so the APK goes with the same release.
val appVersion = Regex("<key>CFBundleShortVersionString</key>\\s*<string>([0-9.]+)</string>")
    .find(rootProject.file("../App/Info.plist").readText())!!.groupValues[1]

// Release signing: a key kept outside the repository (scripts/build-android-app.sh release).
val signingFile = file(System.getenv("TATAKIKUN_ANDROID_SIGNING")
    ?: "${System.getProperty("user.home")}/.config/tatakikun/android-signing.properties")
val signing = Properties().apply { if (signingFile.exists()) signingFile.inputStream().use { load(it) } }

android {
    namespace = "com.tatakikun.android"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    defaultConfig {
        applicationId = "com.tatakikun.android"
        minSdk = 28
        targetSdk = 36
        // 0.6.3 → 603: goes up with every release.
        versionCode = appVersion.split(".").map { it.toInt() }.let { it[0] * 10000 + it[1] * 100 + it[2] }
        versionName = appVersion
        // The engine is built for arm64 (phones, and the emulator on Apple silicon).
        ndk { abiFilters += "arm64-v8a" }
        externalNativeBuild { cmake { arguments += "-DANDROID_STL=c++_shared" } }
    }

    signingConfigs {
        if (signingFile.exists()) create("release") {
            storeFile = file(signing.getProperty("storeFile"))
            storePassword = signing.getProperty("storePassword")
            keyAlias = signing.getProperty("keyAlias")
            keyPassword = signing.getProperty("keyPassword")
        }
    }
    buildTypes {
        release { signingConfig = signingConfigs.findByName("release") }
    }

    externalNativeBuild {
        cmake { path = file("src/main/cpp/CMakeLists.txt") }
    }

    // The language packs are copied out of the APK once; stored, they copy faster.
    androidResources { noCompress += "ttkd" }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) } }
