import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signature de production : chargée depuis android/key.properties (jamais
// commité, voir .gitignore). Si le fichier est absent (clone frais sans le
// keystore), on NE retombe PAS silencieusement sur les clés debug : tout
// build *Release échoue explicitement au moment de l'exécution (voir le
// bloc `gradle.taskGraph.whenReady` plus bas et android/SIGNING.md).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeystoreProperties = keystorePropertiesFile.exists()
if (hasKeystoreProperties) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Firebase Cloud Messaging : le plugin google-services n'est appliqué que si
// android/app/google-services.json existe. Ainsi, l'app se compile normalement
// tant que le projet Firebase n'a pas été créé (push réel désactivé, repli poll).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.payflex.app.payflex_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.payflex.app.payflex_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 32-bit (armeabi-v7a) + 64-bit (arm64-v8a) — couvre tous les téléphones Android réels.
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    signingConfigs {
        create("release") {
            if (hasKeystoreProperties) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
            // Si key.properties est absent, cette config reste délibérément
            // vide : voir la vérification `gradle.taskGraph.whenReady` ci-dessous
            // qui bloque tout build release avec un message clair plutôt que de
            // laisser AGP échouer avec une erreur de signature moins explicite,
            // ou pire, de signer silencieusement avec les clés debug.
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Garde-fou : un build release sans keystore de production est une erreur de
// configuration (pas un cas à ignorer). On échoue explicitement et tôt,
// avant l'exécution des tâches, avec des instructions de résolution.
gradle.taskGraph.whenReady {
    val runningReleaseBuild = allTasks.any { task ->
        task.name.contains("Release") &&
            (task.path.startsWith(":app:")) &&
            (task.name.startsWith("assemble") || task.name.startsWith("bundle") || task.name.startsWith("package") || task.name.startsWith("sign"))
    }
    if (runningReleaseBuild && !hasKeystoreProperties) {
        throw GradleException(
            "android/key.properties introuvable : impossible de signer un build release avec " +
                "les clés debug (bloqué volontairement, publication Play Store impossible sinon). " +
                "Copiez android/key.properties.example vers android/key.properties et renseignez " +
                "vos identifiants de signature. Voir android/SIGNING.md pour la procédure complète."
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
