// The PocketIDE Linux add-on (1.5.128), GPL like the rest of this repository: a small app with no code of its own that holds
// PRoot, its loader and talloc (runtime/build-proot.sh) for the MIT edition of PocketIDE, which carries no GPL code. Android 10+
// lets apps run programs only from an installed APK's library folder; the MIT edition runs them from this app's folder
// (LinuxAddon.kt), and only when this app is signed with the same key, so the signing setup below matches app/.
//
// It also builds on its own, in the public github.com/dbal2969-ai/pocketide-linux-addon (1.5.130), where there is no app/ and
// the recipe is in recipe/ instead of runtime/. There, sign with your own key: -PaddonKeystore=<file> (and addonKeyAlias,
// addonStorePassword, addonKeyPassword when they are not the debug defaults); without one, Android's usual debug key is used.
// PocketIDE uses an add-on only when it is signed like PocketIDE itself, so a self-built add-on works with a self-built app.
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
            val given = findProperty("addonKeystore") as String?
            val keystore = given?.let { rootProject.file(it) } ?: rootProject.file("app/debug.keystore")
            if (keystore.isFile) {
                storeFile = keystore
                if (given == null) storeType = "pkcs12"
                storePassword = findProperty("addonStorePassword") as String? ?: "android"
                keyAlias = findProperty("addonKeyAlias") as String? ?: "androiddebugkey"
                keyPassword = findProperty("addonKeyPassword") as String? ?: "android"
            }
        }
    }

    // PRoot runs as a program, so its files must be extracted to nativeLibraryDir, not left inside the APK.
    packaging {
        jniLibs {
            useLegacyPackaging = true
            keepDebugSymbols += setOf("**/libproot.so", "**/libproot-loader.so")
        }
    }

    // runtime/ in the GPL repository, recipe/ in the add-on's own repository
    val out = listOf("runtime/out", "recipe/out").map { rootProject.file(it) }.firstOrNull { it.isDirectory } ?: rootProject.file("runtime/out")
    sourceSets.getByName("main") {
        jniLibs.srcDir(File(out, "jniLibs"))
        assets.srcDir(File(out, "assets"))   // PRoot's and talloc's licence notices
    }
}
