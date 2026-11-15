plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google Services (Firebase) is applied only when the developer has provisioned
// android/app/google-services.json. Without it the app builds and runs with all
// local features enabled; cloud sync is reported as inactive in Settings.
val googleServicesFile = file("google-services.json")
if (googleServicesFile.exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "id.nara.voice"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = "id.nara.voice"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        jniLibs {
            // Compress native libraries so the APK installs on every device
            // package installer (some OEM/Go installers reject APKs whose
            // .so files are stored uncompressed with INSTALL_FAILED_INVALID_APK).
            useLegacyPackaging = true
        }
    }

    signingConfigs {
        // Enable every signature scheme on the debug key used for release:
        // v1 (JAR) keeps older/OEM package installers happy, v2/v3 cover
        // modern Android. Maximum sideload compatibility costs nothing here.
        getByName("debug") {
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
        }
    }

    buildTypes {
        release {
            // Signed with the debug key so the artifact is installable out of the box.
            // For Play Store distribution generate a proper upload keystore and swap
            // this config — see docs/roadmap.md.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
