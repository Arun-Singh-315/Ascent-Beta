plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.arun.ascent"

    // API 36 required for new Play Store submissions from August 31, 2026 onward.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Enable desugaring so java.time APIs work on older Android versions
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.arun.ascent"
        minSdk = 24          // Android 7.0 — ~99%+ device coverage
        targetSdk = 36       // Required as of August 31, 2026
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Enable multidex (needed when dependency count is high)
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Minification + resource shrinking for release builds
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // TODO: Replace debug signing with a proper release keystore before Play Store upload.
            // Use Play App Signing (enroll at first upload to Play Console).
            signingConfig = signingConfigs.getByName("debug")
        }
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }

    // Ensure 64-bit support (Flutter default already produces this; explicitly state it)
    splits {
        abi {
            isEnable = false // Build universal AAB, not split APKs
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Required for java.time API desugaring on Android < 26
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")
}

flutter {
    source = "../.."
}
