import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// La llave con la que se firma la APK. Android solo instala una versión nueva
// encima de la anterior si las dos llevan la misma firma, así que es siempre
// la misma: en el PC, `android/key.properties` (no se sube: apunta a la llave
// guardada fuera del repositorio); en GitHub Actions, los secretos
// ANDROID_LLAVE_* (ver .github/workflows/publicar.yml). Sin ninguno de los
// dos, se firma con la llave de depuración (solo para pruebas).
val firma = Properties().apply {
    val archivo = rootProject.file("key.properties")
    if (archivo.exists()) archivo.inputStream().use { load(it) }
    System.getenv("ANDROID_LLAVE_ARCHIVO")?.let {
        setProperty("storeFile", it)
        setProperty("storePassword", System.getenv("ANDROID_LLAVE_CLAVE"))
        setProperty("keyAlias", System.getenv("ANDROID_LLAVE_ALIAS") ?: "videoteca")
        setProperty("keyPassword", System.getenv("ANDROID_LLAVE_CLAVE"))
    }
}

android {
    namespace = "io.github.ayoamaro.videoteca"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (firma.getProperty("storeFile") != null) {
            create("videoteca") {
                storeFile = file(firma.getProperty("storeFile"))
                storePassword = firma.getProperty("storePassword")
                keyAlias = firma.getProperty("keyAlias")
                keyPassword = firma.getProperty("keyPassword")
            }
        }
    }

    defaultConfig {
        applicationId = "io.github.ayoamaro.videoteca"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("videoteca")
                ?: signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
