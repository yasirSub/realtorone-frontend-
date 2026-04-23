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
            if (keystorePropertiesFile.exists()) {
                val localStoreFilePath = keystoreProperties["storeFile"] as String?
                    ?: throw GradleException("key.properties missing 'storeFile'")
                val localStorePassword = keystoreProperties["storePassword"] as String?
                    ?: throw GradleException("key.properties missing 'storePassword'")
                val localKeyAlias = keystoreProperties["keyAlias"] as String?
                    ?: throw GradleException("key.properties missing 'keyAlias'")
                val localKeyPassword = keystoreProperties["keyPassword"] as String?
                    ?: throw GradleException("key.properties missing 'keyPassword'")

                signingConfig = signingConfigs.create("release") {
                    this.keyAlias = localKeyAlias
                    this.keyPassword = localKeyPassword
                    this.storeFile = file(localStoreFilePath)
                    this.storePassword = localStorePassword
                }
            } else {
                logger.warn("Missing android/key.properties. Release build will fail to sign.")
            }
        }
    }
}

flutter {
    source = "../.."
}

