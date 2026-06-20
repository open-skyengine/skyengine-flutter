import org.gradle.api.tasks.bundling.Zip

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val mythroadSystemAssetsDir = layout.buildDirectory.dir("generated/assets/mythroadSystem")
val packageMythroadSystem by tasks.registering(Zip::class) {
    archiveFileName.set("mythroad_system.zip")
    destinationDirectory.set(mythroadSystemAssetsDir)
    from("../../mythroad/system") {
        into("system")
    }
}

android {
    namespace = "cn.jysafe.skyengine"
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
        applicationId = "cn.jysafe.skyengine"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        externalNativeBuild {
            cmake {
                arguments += "-DVMRP_BUILD_SHARED_ONLY=ON"
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("../../vmrp/CMakeLists.txt")
            version = "3.18.1+"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    sourceSets {
        getByName("main").assets.srcDir(mythroadSystemAssetsDir)
    }
}

tasks.matching { it.name.startsWith("merge") && it.name.endsWith("Assets") }
    .configureEach {
        dependsOn(packageMythroadSystem)
    }

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
}
