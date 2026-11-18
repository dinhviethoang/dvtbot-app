allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    fun fixSubproject() {
        val android = project.extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                val current = getNamespace.invoke(android) as? String
                if (current.isNullOrEmpty()) {
                    setNamespace.invoke(android, "com.example.${project.name.replace("-", "_")}")
                }
            } catch (e: Exception) {
            }

            try {
                val setCompileSdk = android.javaClass.methods.firstOrNull { 
                    it.name == "setCompileSdk" && it.parameterCount == 1 
                }
                setCompileSdk?.invoke(android, 36)
            } catch (e: Exception) {
            }
            try {
                val setCompileSdkVersion = android.javaClass.methods.firstOrNull { 
                    it.name == "setCompileSdkVersion" && it.parameterCount == 1 
                }
                setCompileSdkVersion?.invoke(android, 36)
            } catch (e: Exception) {
            }
        }


    }

    if (project.state.executed) {
        fixSubproject()
    } else {
        afterEvaluate {
            fixSubproject()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
