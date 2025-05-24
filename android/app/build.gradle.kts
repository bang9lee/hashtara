import java.util.Properties
import java.io.FileInputStream

// 키스토어 설정
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // 구글 서비스 플러그인 추가
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.hashtara.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    // 서명 설정 추가
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // 다음 라인 추가: Desugaring 지원
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.hashtara.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23  // 구글 로그인을 위해 최소 SDK 버전 21로 설정
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
        multiDexEnabled = true  // 추가: 멀티덱스 활성화
        manifestPlaceholders += mapOf(
            "com.google.firebase.messaging.default_notification_channel_id" to "hashtara_notifications",
            "com.google.firebase.messaging.default_notification_icon" to "@mipmap/ic_launcher"
        )
    }

    buildTypes {
        release {
            // 릴리즈 서명 설정으로 변경
            signingConfig = signingConfigs.getByName("release")
            // R8 최적화 비활성화 (임시)
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:32.3.1"))
    // Firebase 분석
    implementation("com.google.firebase:firebase-analytics-ktx")
    // Firebase 인증
    implementation("com.google.firebase:firebase-auth-ktx")
    // Google 로그인
    implementation("com.google.android.gms:play-services-auth:20.6.0")
    // 멀티덱스 지원
    implementation("androidx.multidex:multidex:2.0.1")
    // Desugaring 라이브러리
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("com.google.firebase:firebase-messaging:23.3.1")
}