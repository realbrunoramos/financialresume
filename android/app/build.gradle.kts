plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    //id("com.google.gms.google-services")
}

android {
    namespace = "com.example.financialresume"
    compileSdk = flutter.compileSdkVersion
    //compileSdk = 35
    ndkVersion = "27.0.12077973"
    /*ndkVersion = flutter.ndkVersion*/

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11//JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11//JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true

    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.financialresume"
        minSdk = 23//flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }
    dependencies {
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    }
/*    dependencies {
        // Import the Firebase BoM
        implementation(platform("com.google.firebase:firebase-bom:34.3.0"))


        // TODO: Add the dependencies for Firebase products you want to use
        // When using the BoM, don't specify versions in Firebase dependencies
        implementation("com.google.firebase:firebase-analytics")


        // Add the dependencies for any other desired Firebase products
        // https://firebase.google.com/docs/android/setup#available-libraries
    }*/
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")

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
