pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    // Kotlin 2.4 is required to read the 2.4 metadata of Firebase SDK 25.
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
    // Google Services is applied conditionally in app/build.gradle.kts: only when
    // android/app/google-services.json exists. This keeps `flutter build` working
    // for developers who have not provisioned a Firebase project yet.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
