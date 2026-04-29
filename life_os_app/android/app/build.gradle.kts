import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.life_os_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.life_os_app"
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

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

flutter {
    source = "../.."
}

val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { load(it) }
    }
}

val androidSdkDir = localProperties.getProperty("sdk.dir")
val resolvedNdkDir = if (androidSdkDir.isNullOrBlank()) {
    null
} else {
    file("$androidSdkDir/ndk/${android.ndkVersion}")
}

val buildRustAndroidLibs = tasks.register<Exec>("buildRustAndroidLibs") {
    group = "build"
    description = "Builds the Rust FFI library for Android ABIs before packaging."
    workingDir = file("../../..")
    if (resolvedNdkDir != null) {
        environment("ANDROID_HOME", androidSdkDir)
        environment("ANDROID_SDK_ROOT", androidSdkDir)
        environment("ANDROID_NDK_HOME", resolvedNdkDir.absolutePath)
        environment("ANDROID_NDK_ROOT", resolvedNdkDir.absolutePath)
    }
    commandLine(
        "cargo",
        "ndk",
        "-t",
        "arm64-v8a",
        "-t",
        "armeabi-v7a",
        "-t",
        "x86_64",
        "-o",
        file("src/main/jniLibs").absolutePath,
        "build",
        "--release",
    )
}

tasks.named("preBuild").configure {
    dependsOn(buildRustAndroidLibs)
}
