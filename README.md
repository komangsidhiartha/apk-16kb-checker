# 🔎 apk-16kb-checker

A simple shell script to detect `.so` (native) libraries inside an Android APK that **still use 4 KB page alignment**, which is **not compatible with Android 15+** (requires **16 KB page alignment**).

---

## 🚀 Why This Exists

Starting from **Android 15 (API 35)**, the platform introduces **16 KB page size** support on some devices.
If your native libraries are aligned to **4 KB pages**, your app may **crash or fail to load `.so` files**.

This tool helps developers **scan APKs** to find `.so` files that **still use 4 KB alignment**.

---

## 🧠 How It Works

1.  Extracts all `.so` files from your APK.
2.  Uses `llvm-readelf` (from the Android NDK) to inspect the ELF headers.
3.  Detects whether the **LOAD alignment** is `0x1000` (❌ 4 KB), `0x4000` (✅ 16 KB), or `0x10000` (✅ 64 KB | 4x16KB).

---

## 🧩 Example Output

```bash
🔍 Extracting .so files from build/app/outputs/flutter-apk/app-release.apk …
📂 /tmp/tmp.M1hLdvzF9a/lib/arm64-v8a/libtensorflowlite_jni.so
→ LOAD alignment: 0x1000
⚠️  Uses 4 KB pages (NOT compatible with Android 15+)
📂 /tmp/tmp.M1hLdvzF9a/lib/x86_64/libffmpegkit.so
→ LOAD alignment: 0x1000
⚠️  Uses 4 KB pages (NOT compatible with Android 15+)
28 .so files need to be fixed (arm64-v8a & x86_64 only)
```

---

## 🧰 Requirements

-   **macOS** or **Linux**
-   **`unzip`** (typically pre-installed)
-   **Android NDK** (for `llvm-readelf`)

The script will try to find your NDK automatically. If it can't, you can set your `ANDROID_NDK_HOME` environment variable or use the `--ndk-version` flag.

---

## ⚙️ Usage

### 1) First-time setup

Make the script executable:
```bash
chmod +x apk-16kb-checker.sh
```

### 2) Basic usage

Run the script (default APK path is `build/app/outputs/flutter-apk/app-release.apk`):

```bash
./apk-16kb-checker.sh
```

---

### 3) Custom APK path

```bash
./apk-16kb-checker.sh --apk-path path/to/your.apk
```

---

### 4) Custom NDK version (used to locate `readelf`)

This assumes your NDK is installed at the standard Android SDK path.

```bash
./apk-16kb-checker.sh --ndk-version 28.2.13676358
```

---

### 5) Build before checking (for Flutter projects)

This will run `fvm flutter build apk --release` (or `flutter build...` if FVM isn't found) and then check the resulting APK.

```bash
./apk-16kb-checker.sh --build
```

---

## 🧪 Example Integration (CI/CD)

The script is CI-friendly. It will **automatically exit with a non-zero error code** if it finds any non-compliant 4 KB files.

This means you can drop it directly into your pipeline, and it will fail the build if a bad `.so` is found.

```yaml
- name: Check APK 16KB compliance
  run: |
    ./apk-16kb-checker.sh --apk-path build/app/outputs/flutter-apk/app-release.apk
```
No need for `grep` or complex checks.

---

## 🧠 How to Fix

If you find 4 KB-aligned `.so` files, you have several options:

### 1. Upgrade the Dependency (Best Option)
Many libraries (like `objectbox`, `ffmpeg_kit_flutter`, `google_mlkit_*`) have released 16KB-compatible versions. Upgrading the package in your `pubspec.yaml` is the cleanest fix.

### 2. Force a Transitive Dependency (The Conflict Fix)
Sometimes, the problem is a **conflict**, like between the `camera` plugin and `google_mlkit`. The `camera` plugin may use an old `androidx.camera:camera-core` library that contains a non-compliant file.

The fix is to force a newer version in your **`android/app/build.gradle`**:

```groovy
// File: android/app/build.gradle
dependencies {
    // ... your other dependencies

    // ADD THIS BLOCK
    constraints {
        implementation('androidx.camera:camera-core:1.4.0-rc01') {
            because 'Version 1.3.4 contains a non-16KB-aligned native library'
        }
    }
}
```

### 3. Rebuild from Source (Manual)
If you control the native code, rebuild the library using **NDK r28+** with the linker flag:
```
-Wl,-z,max-page-size=16384
```

**Note:** Only **`arm64-v8a`** and **`x86_64`** are affected for Android 15+. 32-bit ABIs remain 4 KB-aligned.

---

## 📝 License

MIT License © 2025 Komang Sidhi Artha

---

## 💬 Acknowledgements

Thanks to the Android and Flutter communities for sharing early guidance and examples for handling **16 KB page alignment** issues in native builds.

---

> 🧩 “Check early, fix early — before your users hit Android 15.”
