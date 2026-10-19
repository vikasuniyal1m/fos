import java.util.Properties
// 1. Ye block Properties read karne ke liye hai
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
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
        // ABI filters: let Flutter control via --split-per-abi / --target-platform
        // (manual ndk.abiFilters conflicts with flutter build apk --split-per-abi)
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
    // Force Google Play Billing 9.0.0 for release artifacts.
    implementation("com.android.billingclient:billing:9.0.0")

    // Play Billing 8+ comes from in_app_purchase_android >= 0.5.0 (via in_app_purchase ^3.3.0)

    // Material Components theme required by flutter_stripe (Theme.MaterialComponents)
    implementation("com.google.android.material:material:1.11.0")
    // Firebase dependencies REMOVED - not using Firebase
    implementation(kotlin("stdlib-jdk8"))
}
