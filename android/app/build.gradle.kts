import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // Built-in Kotlin (AGP 9+). Do not apply kotlin-android / KGP — see Flutter migration guide.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Read app version from pubspec.yaml so Android version stays in sync.
data class PubspecVersion(val name: String, val code: Int)

fun readPubspecVersion(): PubspecVersion? {
    val pubspec = rootProject.file("../pubspec.yaml")
    if (!pubspec.exists()) return null
    val versionLine = pubspec.readLines()
        .firstOrNull { it.trim().startsWith("version:") }
        ?.substringAfter("version:")
        ?.trim()
        ?: return null

    val match = Regex("""^([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$""").find(versionLine)
        ?: return null
    val name = match.groupValues[1]
    val code = match.groupValues[2].toIntOrNull() ?: return null
    return PubspecVersion(name = name, code = code)
}

val pubspecVersion = readPubspecVersion()

android {
    namespace = "com.realtorone.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.realtorone.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = pubspecVersion?.code ?: flutter.versionCode
        versionName = pubspecVersion?.name ?: flutter.versionName
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
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

                val localStoreFile = file(localStoreFilePath)
                if (!localStoreFile.exists()) {
                    logger.warn("Keystore file '${localStoreFile.absolutePath}' not found. Falling back to debug signing for local builds.")
                    signingConfig = signingConfigs.getByName("debug")
                } else {
                    signingConfig = signingConfigs.create("release") {
                        this.keyAlias = localKeyAlias
                        this.keyPassword = localKeyPassword
                        this.storeFile = localStoreFile
                        this.storePassword = localStorePassword
                    }
                }
            } else {
                logger.warn("Missing android/key.properties. Release build will use debug signing for local builds (not for Play Store).")
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
