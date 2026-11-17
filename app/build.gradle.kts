import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.github.triplet.play")
}

// Release secrets, kept out of git: the Play upload key (storeFile, storePassword, keyAlias, keyPassword)
// and the path to the Play Developer API service account JSON (playServiceAccount).
val secrets = Properties().apply {
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
        versionCode = 5
        versionName = "0.5"
    }

    signingConfigs {
        if (secrets.containsKey("storeFile")) create("upload") {
            storeFile = rootProject.file(secrets.getProperty("storeFile"))
            storePassword = secrets.getProperty("storePassword")
            keyAlias = secrets.getProperty("keyAlias")
            keyPassword = secrets.getProperty("keyPassword")
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

// ./gradlew publishBundle uploads a release to internal testing; ./gradlew publishListing pushes src/main/play.
play {
    secrets.getProperty("playServiceAccount")?.let { serviceAccountCredentials.set(rootProject.file(it)) }
    track.set("internal")
    defaultToAppBundles.set(true)
}
