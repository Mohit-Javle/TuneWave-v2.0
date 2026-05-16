import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.tunewave.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            val alias = keyProperties.getProperty("keyAlias")
            val keyPass = keyProperties.getProperty("keyPassword")
            val store = keyProperties.getProperty("storeFile")
            val storePass = keyProperties.getProperty("storePassword")

            if (alias != null && keyPass != null && store != null && storePass != null) {
                keyAlias = alias
                keyPassword = keyPass
                storeFile = file(store)
                storePassword = storePass
            }
        }
    }

    defaultConfig {
        applicationId = "com.tunewave.app"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Code shrinking disabled temporarily for compatibility
            // Enable after testing: isMinifyEnabled = true, isShrinkResources = true
            isMinifyEnabled = false
            isShrinkResources = false
            
            val isSigningConfigComplete = keyProperties.getProperty("keyAlias") != null &&
                                          keyProperties.getProperty("keyPassword") != null &&
                                          keyProperties.getProperty("storeFile") != null &&
                                          keyProperties.getProperty("storePassword") != null
            
            if (isSigningConfigComplete) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    flavorDimensions += "environment"

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }
        create("prod") {
            dimension = "environment"
        }
    }
}

flutter {
    source = "../.."
    }