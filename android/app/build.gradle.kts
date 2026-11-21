plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signature officielle de Zéro Perte.
// La clé n'est JAMAIS dans le dépôt en clair : GitHub Actions la déchiffre dans un
// dossier temporaire et transmet son chemin et son mot de passe par variables
// d'environnement (voir .github/workflows/fabriquer-apk.yml).
// Sans ces variables (fabrication d'essai ou sur un ordinateur de développement),
// l'APK est signé avec la clé de débogage et ne doit PAS être distribué.
val cleChemin: String? = System.getenv("ZP_CLE_CHEMIN")
val cleMotDePasse: String? = System.getenv("ZP_CLE_MOT_DE_PASSE")
val cleAlias: String = System.getenv("ZP_CLE_ALIAS") ?: "zeroperte"
val signatureOfficielle = !cleChemin.isNullOrEmpty() && !cleMotDePasse.isNullOrEmpty()

android {
    namespace = "tg.zeroperte.app"

    // APK plus léger à télécharger (WhatsApp) : les bibliothèques natives sont
    // compressées dans l'APK (Android les décompresse à l'installation).
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identifiant définitif : il ne pourra plus jamais changer.
        applicationId = "tg.zeroperte.app"
        // Android 8.0 minimum (décision du propriétaire).
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signatureOfficielle) {
            create("officielle") {
                storeFile = file(cleChemin!!)
                storeType = "PKCS12"
                storePassword = cleMotDePasse
                keyAlias = cleAlias
                keyPassword = cleMotDePasse
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (signatureOfficielle) {
                signingConfigs.getByName("officielle")
            } else {
                signingConfigs.getByName("debug")
            }
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

dependencies {
    // FileProvider : partager l'image du reçu avec WhatsApp.
    implementation("androidx.core:core:1.13.1")
}
