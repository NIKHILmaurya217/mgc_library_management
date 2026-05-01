plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration // KEEP THIS AS IS
    id("kotlin-android")         // KEEP THIS AS IS
    id("dev.flutter.flutter-gradle-plugin") // KEEP THIS AS IS
}

android {
    // 1. Update namespace to match your new ID
    namespace = "com.nikhil.mgc_management" 
    
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
        // 2. This is where your unique ID goes!
        applicationId = "com.mgc.app"
        
        // 3. Manually set minSdk to 23 for Firebase compatibility
        minSdk = flutter.minSdkVersion 
        
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
