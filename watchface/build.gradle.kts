plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace = "com.example.verlwatchface"
    compileSdk {
        version = release(37)
    }

    defaultConfig {
        applicationId = "com.example.verlwatchface"
        minSdk = 36
        targetSdk = 37
        versionCode = 1
        versionName = "1.0"

    }

    buildTypes {
        release {
            optimization {
                enable = true
                packageScope = setOf("androidx.**", "kotlin.**", "kotlinx.**")
            }
        }
    }
    enableKotlin = false
}

dependencies {
}