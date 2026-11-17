import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// Play upload key, kept out of git: storeFile, storePassword, keyAlias, keyPassword.
val uploadKey = Properties().apply {
    val f = rootProject.file("keystore.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "dev.natya.opendictate"
    compileSdk = 36

    defaultConfig {
        applicationId = "dev.natya.opendictate"
        minSdk = 26
        targetSdk = 36
        versionCode = 3
        versionName = "0.3"
    }

    signingConfigs {
        if (uploadKey.isNotEmpty()) create("upload") {
            storeFile = rootProject.file(uploadKey.getProperty("storeFile"))
            storePassword = uploadKey.getProperty("storePassword")
            keyAlias = uploadKey.getProperty("keyAlias")
            keyPassword = uploadKey.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            // Upload key when keystore.properties exists; otherwise the debug key, so a fresh clone still builds an installable APK.
            signingConfig = signingConfigs.findByName("upload") ?: signingConfigs.getByName("debug")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures { buildConfig = true }
    kotlinOptions { jvmTarget = "17" }
    dependenciesInfo { includeInApk = false; includeInBundle = false }
    packaging { resources { excludes += listOf("kotlin/**", "META-INF/**", "DebugProbesKt.bin") } }
}
