import java.util.Properties
import java.io.FileInputStream



plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}


android {
    namespace = "com.mlq.my_leadership_quest"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.0.12674087"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // Fix for 16 KB page size support (Android 15+)
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }
    
    // Enable 16 KB page alignment for Android 15+ devices
    @Suppress("UnstableApiUsage")
    androidResources {
        // Align uncompressed native libraries to 16KB boundaries
    }

    defaultConfig {
        applicationId = "com.mlq.my_leadership_quest"
        minSdk = 24  // Updated from flutter.minSdkVersion (23) to meet Flutter's upcoming requirement
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Support for 16 KB page sizes
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // Fallback to debug signing if key.properties doesn't exist
                signingConfigs.getByName("debug")
            }
            // Enable code shrinking and obfuscation for smaller app size
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // Use modern Play Feature Delivery (replaces deprecated play-core) for SplitInstall APIs, SDK 34 compatible
    implementation("com.google.android.play:feature-delivery:2.1.0")
    // Optional KTX extensions (safe even if not directly used by app code)
    implementation("com.google.android.play:feature-delivery-ktx:2.1.0")
    
    // Android 15 edge-to-edge support - updated to latest stable versions
    implementation("androidx.activity:activity-ktx:1.9.3")
    implementation("androidx.core:core-ktx:1.15.0")
}
