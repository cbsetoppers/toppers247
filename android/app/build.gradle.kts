import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val downloadsDir = System.getProperty("user.home") + "/Downloads"

android {
    namespace = "com.cbsetoppers.learning"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    @Suppress("DEPRECATION")
    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        applicationId = "com.cbsetoppers.learning"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        resValue("string", "app_name", "TOPPERS 24/7")
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

tasks.register<Delete>("cleanAppBuilds") {
    delete(file("build"))
    delete(file("app/build"))
}

afterEvaluate {
    val releaseTask = tasks.findByName("assembleRelease")
    releaseTask?.let { task ->
        task.doFirst {
            val dir = file("build/app/outputs/flutter-apk")
            if (dir.exists()) {
                dir.listFiles()?.filter { it.name.endsWith(".apk") }?.forEach { it.delete() }
            }
        }
        task.doLast {
            val buildDir = file("build/app/outputs/flutter-apk")
            if (buildDir.exists()) {
                buildDir.listFiles()?.filter { it.name.endsWith(".apk") }?.forEach { apkFile ->
                    val chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
                    val buildId = (1..6).map { chars.random() }.joinToString("")
                    val newName = "TOPPERS 24 7 (v${buildId}).apk"
                    copy {
                        from(apkFile)
                        into(downloadsDir)
                        rename { newName }
                    }
                    println("✅ APK saved to Downloads: $newName")
                }
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("androidx.multidex:multidex:2.0.1")
}
