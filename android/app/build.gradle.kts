import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.storia.storia_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.storia.storia_flutter"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        jniLibs {
            // flutter_midi_pro and flutter_soloud both bundle these codecs; either copy is fine.
            pickFirsts += setOf(
                "lib/arm64-v8a/libFLAC.so",
                "lib/armeabi-v7a/libFLAC.so",
                "lib/x86/libFLAC.so",
                "lib/x86_64/libFLAC.so",
                "lib/arm64-v8a/libogg.so",
                "lib/armeabi-v7a/libogg.so",
                "lib/x86/libogg.so",
                "lib/x86_64/libogg.so",
                "lib/arm64-v8a/libopus.so",
                "lib/armeabi-v7a/libopus.so",
                "lib/x86/libopus.so",
                "lib/x86_64/libopus.so",
                "lib/arm64-v8a/libvorbis.so",
                "lib/armeabi-v7a/libvorbis.so",
                "lib/x86/libvorbis.so",
                "lib/x86_64/libvorbis.so",
                "lib/arm64-v8a/libvorbisfile.so",
                "lib/armeabi-v7a/libvorbisfile.so",
                "lib/x86/libvorbisfile.so",
                "lib/x86_64/libvorbisfile.so",
            )
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as? String
            keyPassword = keystoreProperties["keyPassword"] as? String
            storeFile = (keystoreProperties["storeFile"] as? String)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as? String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}