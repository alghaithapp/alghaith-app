import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Agora voice-only: exclude video/screen native extensions only (keep audio libs).
val agoraNativeAbis = listOf("arm64-v8a", "armeabi-v7a", "x86_64", "x86")
val agoraExcludedVideoExtensions = listOf(
    "libagora_clear_vision_extension.so",
    "libagora_lip_sync_extension.so",
    "libagora_spatial_audio_extension.so",
    "libagora_segmentation_extension.so",
    "libagora_face_capture_extension.so",
    "libagora_face_detection_extension.so",
    "libagora_video_encoder_extension.so",
    "libagora_video_decoder_extension.so",
    "libagora_video_av1_encoder_extension.so",
    "libagora_video_av1_decoder_extension.so",
    "libagora_video_quality_analyzer_extension.so",
    "libagora_screen_capture_extension.so",
    "libagora_content_inspect_extension.so",
    "libagora_super_resolution_extension.so",
    "libagora_video_segmentation_extension.so",
    "libagora_replay_kit_extension.so",
)

android {
    namespace = "com.alghaith.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        applicationId = "com.alghaith.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    packaging {
        jniLibs {
            agoraNativeAbis.forEach { abi ->
                agoraExcludedVideoExtensions.forEach { library ->
                    excludes += "lib/$abi/$library"
                }
            }
        }
    }
}

configurations.all {
    resolutionStrategy.eachDependency {
        if (requested.group == "androidx.browser" && requested.name == "browser") {
            useVersion("1.8.0")
        }
        if (requested.group == "androidx.core" && requested.name == "core-ktx") {
            useVersion("1.13.1")
        }
        if (requested.group == "androidx.core" && requested.name == "core") {
            useVersion("1.13.1")
        }
    }
}

flutter {
    source = "../.."
}

if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
