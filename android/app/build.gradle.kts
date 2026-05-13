import java.util.Properties
// 1. Ye block Properties read karne ke liye hai
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}
plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // id("com.google.gms.google-services") // DISABLED - Firebase not used
}

android {
    namespace = "com.fruitsofspirit.android"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        jvmToolchain(17)
    }

    signingConfigs {
        getByName("debug") {
            keyAlias = "androiddebugkey"
            keyPassword = "android"
            storeFile = file("debug.keystore")
            storePassword = "android"
        }
        create("release") {
            val keyAliasStr = keystoreProperties["keyAlias"] as? String
            val keyPasswordStr = keystoreProperties["keyPassword"] as? String
            val storeFileStr = keystoreProperties["storeFile"] as? String
            val storePasswordStr = keystoreProperties["storePassword"] as? String

            if (keyAliasStr != null && keyPasswordStr != null && storeFileStr != null && storePasswordStr != null) {
                keyAlias = keyAliasStr
                keyPassword = keyPasswordStr
                storeFile = rootProject.file(storeFileStr)
                storePassword = storePasswordStr
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.fruitsofspirit.android"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion // Android 6.0+ (was flutter.minSdkVersion which was too high)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Support 16 KB page sizes for Android 15+
        // Note: ndk.abiFilters uses setOf() in Kotlin DSL
        ndk {
            abiFilters.clear()
            abiFilters.addAll(setOf("armeabi-v7a", "arm64-v8a"))
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    
    // By default, Flutter handles `ndk { abiFilters }` internally when you run `flutter run` or `flutter build apk`.
    // Do not use the manual `splits { abi { ... } }` block because it causes conflicts.
}

flutter {
    source = "../.."
}

dependencies {
    // Billing library is handled by in_app_purchase plugin automatically
    // implementation("com.android.billingclient:billing-ktx:8.3.0")

    // Material Components theme required by flutter_stripe (Theme.MaterialComponents)
    implementation("com.google.android.material:material:1.11.0")
    // Firebase dependencies REMOVED - not using Firebase
    implementation(kotlin("stdlib-jdk8"))
}
