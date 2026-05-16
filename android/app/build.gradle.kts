// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("kotlin-android") // This is the KTS equivalent of id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.gena"
    // Use explicit versions instead of 'flutter.sdkVersion' if the errors persist
    compileSdk = 36

    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
        // Crucial for Gemma: skip prerelease checks on native AI libraries
        freeCompilerArgs += listOf("-Xskip-prerelease-check")
    }

    defaultConfig {
        applicationId = "com.example.gena"
        minSdk = flutter.minSdkVersion // Gemma requires at least 21
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
}

dependencies {
    // Manually forcing the MediaPipe GenAI dependency often solves the "Unresolved Reference"
    implementation("com.google.mediapipe:tasks-genai:0.10.14")
}

flutter {
    source = "../.."
}
