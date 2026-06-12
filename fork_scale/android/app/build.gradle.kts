plugins {
    id("com.android.application")
    // kotlin-android is intentionally omitted: the Flutter Gradle Plugin now
    // supplies Kotlin support via "Built-in Kotlin" (flutter.dev/go/built-in-kotlin).
    // Explicitly applying kotlin-android here causes a deprecation warning.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.forkscale.fork_scale"
    compileSdk = flutter.compileSdkVersion
    // Pinned to NDK r27 (XML v3) to avoid CXX5304 warning from NDK r28's XML v4 format.
    ndkVersion = "27.2.12479018"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.forkscale.fork_scale"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
