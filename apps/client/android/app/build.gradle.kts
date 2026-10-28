plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.trinktribunal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Stable APK identity: retain the existing installation/update and data path.
        applicationId = "com.example.trinktribunal"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Der Keystore kommt nur aus Codemagic. Lokal wird keine Debug-Signatur
    // stillschweigend fuer einen Release-Build verwendet.
    val releaseRequested = gradle.startParameter.taskNames.any {
        it.contains("release", ignoreCase = true)
    }
    val missingSigningVariables = listOf(
        "CM_KEYSTORE_PATH", "CM_KEYSTORE_PASSWORD", "CM_KEY_ALIAS", "CM_KEY_PASSWORD"
    ).filter { System.getenv(it).isNullOrBlank() }
    if (releaseRequested && missingSigningVariables.isNotEmpty()) {
        throw GradleException(
            "Release signing requires Codemagic variables: " + missingSigningVariables.joinToString(", ")
        )
    }
    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("CM_KEYSTORE_PATH")
            if (!keystorePath.isNullOrBlank()) {
                storeFile = file(keystorePath)
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("CM_KEY_ALIAS")
                keyPassword = System.getenv("CM_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
