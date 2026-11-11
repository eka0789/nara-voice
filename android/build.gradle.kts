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

// Some Flutter plugins (notably the Firebase ones) pin their own Kotlin Gradle
// plugin version in their per-project buildscript. Firebase Android SDK 25
// ships libraries compiled with Kotlin 2.4 metadata, which older pinned
// compilers cannot read. Gradle resolves duplicate classpath entries to the
// highest declared version, so forcing 2.4.0 here fixes the mismatch.
subprojects {
    buildscript {
        dependencies {
            classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.4.0")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
