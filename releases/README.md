# Ascent Release Manifest

Production and beta APKs are generated via the Flutter build pipeline (`flutter build apk --release`) and distributed via verified release channels. Compiled binary artifacts (`.apk`) are excluded from repository version control to keep the repository lightweight.

For local installation on a connected device:
```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```
