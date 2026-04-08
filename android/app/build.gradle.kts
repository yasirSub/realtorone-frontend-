import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.realtorone.app"
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
        applicationId = "com.realtorone.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (!keystorePropertiesFile.exists()) {
                throw GradleException(
                    "Missing android/key.properties for release signing. " +
                        "Create it with storeFile, storePassword, keyAlias, keyPassword."
                )
            }

            val storeFilePath = keystoreProperties["storeFile"] as String?
                ?: throw GradleException("key.properties missing 'storeFile'")
            val storePassword = keystoreProperties["storePassword"] as String?
                ?: throw GradleException("key.properties missing 'storePassword'")
            val keyAlias = keystoreProperties["keyAlias"] as String?
                ?: throw GradleException("key.properties missing 'keyAlias'")
            val keyPassword = keystoreProperties["keyPassword"] as String?
                ?: throw GradleException("key.properties missing 'keyPassword'")

            signingConfig = signingConfigs.create("release") {
                storeFile = file(storeFilePath)
                this.storePassword = storePassword
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword
            }
        }
    }
}

flutter {
    source = "../.."
}

