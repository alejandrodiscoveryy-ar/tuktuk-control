import com.android.build.api.artifact.SingleArtifact
import org.gradle.api.DefaultTask
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.tasks.InputFile
import org.gradle.api.tasks.OutputFile
import org.gradle.api.tasks.TaskAction
import javax.xml.parsers.DocumentBuilderFactory
import javax.xml.transform.TransformerFactory
import javax.xml.transform.dom.DOMSource
import javax.xml.transform.stream.StreamResult
import org.w3c.dom.Element
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.alejandrocruz.tuktukcontrol"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.alejandrocruz.tuktukcontrol"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val releaseRequested = gradle.startParameter.taskNames.any {
                it.contains("release", ignoreCase = true)
            }
            check(keystorePropertiesFile.exists() || !releaseRequested) {
                "Falta android/key.properties. La compilación release requiere la clave de carga."
            }
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("com.android.installreferrer:installreferrer:2.2")
}


// Mapbox's renderer is used only when GLES 3 is supported. Android's
// manifest merger can retain the library's higher GLES declaration even when
// the source declares GLES 2. Transform the official merged manifest artifact
// before packaging, leaving every other hardware feature and permission intact.
abstract class LegacyGraphicsManifestTask : DefaultTask() {
    @get:InputFile
    abstract val inputManifest: RegularFileProperty

    @get:OutputFile
    abstract val outputManifest: RegularFileProperty

    @TaskAction
    fun adjustGraphicsRequirement() {
        val ns = "http://schemas.android.com/apk/res/android"
        val factory = DocumentBuilderFactory.newInstance().apply {
            isNamespaceAware = true
            setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)
        }
        val document = factory.newDocumentBuilder().parse(inputManifest.get().asFile)
        val root = document.documentElement
        check(root.tagName == "manifest")
        val features = root.getElementsByTagName("uses-feature")
        val graphics = (0 until features.length)
            .mapNotNull { features.item(it) as? Element }
            .filter { it.parentNode == root && it.hasAttributeNS(ns, "glEsVersion") }
        check(graphics.isNotEmpty()) { "Merged manifest is missing its graphics declaration" }
        val original = graphics.map { it.getAttributeNS(ns, "glEsVersion") }
        check(original.all { Integer.decode(it) in 0x00020000..0x00030000 }) {
            "Unexpected graphics requirement: $original"
        }
        // Only these anonymous OpenGL entries may be changed.
        check(graphics.none { it.hasAttributeNS(ns, "name") })
        graphics.forEach { root.removeChild(it) }
        val feature = document.createElement("uses-feature")
        feature.setAttributeNS(ns, "android:glEsVersion", "0x00020000")
        feature.setAttributeNS(ns, "android:required", "true")
        root.insertBefore(feature, root.firstChild)
        val output = outputManifest.get().asFile
        output.parentFile.mkdirs()
        TransformerFactory.newInstance().newTransformer().transform(
            DOMSource(document), StreamResult(output)
        )
        logger.lifecycle("GRAPHICS_MANIFEST: $original -> 0x00020000; other declarations preserved")
    }
}

// Manifest-only check: no APK, bundle, upload key or production secrets.
val verifyLegacyGraphicsManifest = tasks.register("verifyLegacyGraphicsManifest")
androidComponents.onVariants(androidComponents.selector().withBuildType("release")) { variant ->
    val transform = tasks.register<LegacyGraphicsManifestTask>(
        "normalize${variant.name.replaceFirstChar { it.uppercase() }}GraphicsManifest"
    )
    variant.artifacts.use(transform)
        .wiredWithFiles(LegacyGraphicsManifestTask::inputManifest, LegacyGraphicsManifestTask::outputManifest)
        .toTransform(SingleArtifact.MERGED_MANIFEST)
    verifyLegacyGraphicsManifest.configure {
        dependsOn(transform)
        doLast {
            val output = transform.get().outputManifest.get().asFile
            val factory = DocumentBuilderFactory.newInstance().apply {
                isNamespaceAware = true
                setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)
            }
            val root = factory.newDocumentBuilder().parse(output).documentElement
            val ns = "http://schemas.android.com/apk/res/android"
            val features = root.getElementsByTagName("uses-feature")
            val graphics = (0 until features.length)
                .mapNotNull { features.item(it) as? Element }
                .filter { it.parentNode == root && it.hasAttributeNS(ns, "glEsVersion") }
            check(graphics.size == 1 &&
                Integer.decode(graphics.single().getAttributeNS(ns, "glEsVersion")) == 0x00020000 &&
                graphics.single().getAttributeNS(ns, "required") == "true")
            logger.lifecycle("GRAPHICS_MANIFEST_PREFLIGHT=OK")
        }
    }
}
