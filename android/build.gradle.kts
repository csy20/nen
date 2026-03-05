allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Fix for older plugins (e.g. on_audio_query_android) that don't declare
// a namespace in their build.gradle — required by AGP 8+.
// Also forces Java 17 + Kotlin 17 on ALL subprojects (after their own scripts run).
subprojects {
    if (project.name != "app") {
        afterEvaluate {
            // Fix missing namespace for AGP 8+
            plugins.withType<com.android.build.gradle.LibraryPlugin> {
                val android = extensions.getByType<com.android.build.gradle.LibraryExtension>()
                if (android.namespace.isNullOrEmpty()) {
                    val manifest = file("src/main/AndroidManifest.xml")
                    if (manifest.exists()) {
                        val pkg = Regex("""package\s*=\s*"([^"]+)"""")
                            .find(manifest.readText())?.groupValues?.get(1)
                        if (!pkg.isNullOrEmpty()) {
                            android.namespace = pkg
                        }
                    }
                }
            }
            // Force Java 17 on all Android subprojects (library or app)
            plugins.withType<com.android.build.gradle.BasePlugin> {
                val android = extensions.getByType<com.android.build.gradle.BaseExtension>()
                android.compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
        }
    }
    // Align Kotlin JVM target for all subprojects
    project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
