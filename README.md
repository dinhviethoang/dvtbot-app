# DVTBot Android

Clean and optimized Android application for DVTBot AI Assistant, built with Flutter.

## System Requirements

- **Flutter SDK**: 3.50.0 (Channel stable, Dart 3.14.0)
- **Java Development Kit**: JDK 17 (OpenJDK 17 recommended)
- **Android SDK**: Platform Android 36 (`compileSdk 36`, `minSdk 24`, `targetSdk 34+`)
- **Android NDK**: `28.2.13676358`
- **CMake**: `3.22.1`

## Project Structure

```
dvtbot-app/
├── android/                  # Native Android project files and Gradle configuration
├── assets/                   # Referenced image and app assets
├── lib/                      # Core Flutter application source code
├── key.properties.example    # Template for Android release signing credentials
├── pubspec.yaml              # Project dependencies and asset definitions
├── pubspec.lock              # Pinned dependency lockfile
├── LICENSE                   # Open-source license attribution (Apache-2.0)
└── README.md                 # Project documentation
```

## Setup & Installation

1. Set required environment variables:
   ```bash
   export JAVA_HOME="/path/to/openjdk-17"
   export ANDROID_HOME="/path/to/android-sdk"
   export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
   ```

2. Fetch Flutter dependencies:
   ```bash
   flutter pub get
   ```

3. Verify codebase with analyzer:
   ```bash
   flutter analyze
   ```

## Signing Configuration

To sign release builds, create `android/key.properties` (or `key.properties` in the project root) from the example template:

```bash
cp key.properties.example android/key.properties
```

Edit `android/key.properties` with your keystore credentials:
```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=your_key_alias
storeFile=/absolute/or/relative/path/to/keystore.jks
# Optional keystore type (e.g. PKCS12 or JKS):
# storeType=PKCS12
```

> **Note:** If `key.properties` is not provided, release builds automatically fall back to the Android debug keystore so compilation succeeds without requiring private credentials.

## Build Instructions

### 1. Build Debug APK
```bash
flutter build apk --debug
```
Output:
`build/app/outputs/flutter-apk/app-debug.apk`

### 2. Build Universal Release APK
```bash
flutter build apk --release
```
Output:
`build/app/outputs/flutter-apk/app-release.apk`

### 3. Build Split-per-ABI Release APKs (Optimized size)
```bash
flutter build apk --release --split-per-abi
```
Outputs:
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (32-bit ARM)
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (64-bit ARM)
- `build/app/outputs/flutter-apk/app-x86_64-release.apk` (x86_64 Emulators/Devices)

## License

This project is licensed under the Apache License, Version 2.0. See the [LICENSE](file:///Users/dinhhoang1306/.gemini/antigravity/scratch/dvtbot-app/LICENSE) file for details.
