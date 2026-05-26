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
        isCoreLibraryDesugaringEnabled = true
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

        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    buildTypes {
        release {
            // Keep this if you already use debug signing for local release build
            signingConfig = signingConfigs.getByName("debug")

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

    packaging {
        jniLibs {
            // Better compression for APK distributed outside Play Store.
            // It can reduce APK size, but install may be a bit slower.
            useLegacyPackaging = true
        }

        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/license.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/notice.txt",
                "META-INF/ASL2.0",
                "META-INF/*.kotlin_module",
                "META-INF/versions/**"
            )
        }
    }
}

dependencies {
    // Manually forcing the MediaPipe GenAI dependency often solves the "Unresolved Reference"
    implementation("com.google.mediapipe:tasks-genai:0.10.14")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
