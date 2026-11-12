// The PocketIDE Linux add-on (1.5.128), GPL like the rest of this repository: a small app with no code of its own that holds
// PRoot, its loader and talloc (runtime/build-proot.sh) for the MIT edition of PocketIDE, which carries no GPL code. Android 10+
// lets apps run programs only from an installed APK's library folder; the MIT edition runs them from this app's folder
// (LinuxAddon.kt), and only when this app is signed with the same key, so the signing setup below matches app/.
plugins {
    id("com.android.application")
}

android {
    namespace = "dev.pocketide.linux"
    compileSdk = 36

    defaultConfig {
        applicationId = "dev.pocketide.linux"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
        ndk { abiFilters += setOf("arm64-v8a") }   // PRoot is built for 64-bit ARM phones only
    }

    signingConfigs {
        getByName("debug") {
            storeFile = rootProject.file("app/debug.keystore")
            storeType = "pkcs12"
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    // PRoot runs as a program, so its files must be extracted to nativeLibraryDir, not left inside the APK.
    packaging {
        jniLibs {
            useLegacyPackaging = true
            keepDebugSymbols += setOf("**/libproot.so", "**/libproot-loader.so")
        }
    }

    sourceSets.getByName("main") {
        jniLibs.srcDir(rootProject.file("runtime/out/jniLibs"))
        assets.srcDir(rootProject.file("runtime/out/assets"))   // PRoot's and talloc's licence notices
    }
}
