import org.gradle.api.tasks.bundling.Zip
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val mythroadSystemAssetsDir = layout.buildDirectory.dir("generated/assets/mythroadSystem")
val keystoreProperties =
    Properties().apply {
        val propertiesFile = rootProject.file("key.properties")
        if (propertiesFile.isFile) {
            propertiesFile.inputStream().use(::load)
        }
    }

fun signingProperty(name: String): String? =
    (keystoreProperties.getProperty(name) ?: providers.environmentVariable(name).orNull)
        ?.takeIf { it.isNotBlank() }

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

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "cn.jysafe.skyengine"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }

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

    signingConfigs {
        create("release") {
            val storeFilePath = signingProperty("storeFile")
            if (storeFilePath != null) {
                storeFile = file(storeFilePath)
            }
            storePassword = signingProperty("storePassword")
            keyAlias = signingProperty("keyAlias")
            keyPassword = signingProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    sourceSets {
        getByName("main").assets.srcDir(mythroadSystemAssetsDir)
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
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
