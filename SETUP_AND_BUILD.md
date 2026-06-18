# Vibrate Timer — Setup & Build Guide

A Flutter (Android) app with a **Start / Stop** button. On Start you pick
**5 / 10 / 15 min or a Custom** interval. The phone then **vibrates hard for ~3
seconds at every interval** (e.g. every 5 min: at 5, 10, 15, 20 min…) and keeps
repeating until you press **Stop**. It works **in the background and even if the
app is closed**, using Android's `AlarmManager` (exact, repeating alarms).

---

## 0. Easiest: build the APK on GitHub (no local setup) ⭐

This repo includes a GitHub Actions workflow at
[.github/workflows/build-apk.yml](.github/workflows/build-apk.yml) that builds
the release APK in the cloud — you don't need Flutter/Android tools installed.

1. Create a repo on GitHub and push this project:
   ```bash
   git init
   git add .
   git commit -m "Vibrate Timer app"
   git branch -M main
   git remote add origin https://github.com/<your-username>/<your-repo>.git
   git push -u origin main
   ```
2. Open the repo's **Actions** tab → the **Build APK** workflow runs
   automatically on the push (takes ~5–8 min).
3. When it finishes (green ✓), open the run and download the APK from
   **Artifacts → `vibrate-timer-release-apk`**.

**Want a permanent download link / release?** Push a version tag and the
workflow attaches the APK to a GitHub Release:
```bash
git tag v1.0.0
git push origin v1.0.0
```
The APK then appears under the repo's **Releases** page.

> The CI runner installs Flutter 3.44.2, JDK 17, and auto-downloads the Android
> SDK/NDK — so the build is fully reproducible without touching your machine.

---

## 1. Prerequisites (only if building locally)

You already have on this machine:

- ✅ Android SDK (`platform-tools`, `cmdline-tools`)
- ✅ JDK 21
- ❌ **Flutter SDK — not installed yet** (this is the only missing piece)

### Install Flutter

1. Download the Flutter SDK (stable) for Windows:
   https://docs.flutter.dev/get-started/install/windows
2. Unzip it somewhere without spaces, e.g. `C:\src\flutter`.
3. Add `C:\src\flutter\bin` to your **PATH**.
4. Open a new terminal and verify:
   ```
   flutter --version
   flutter doctor --android-licenses   # accept all
   flutter doctor
   ```
   Resolve anything `flutter doctor` flags (mainly the Android toolchain).

---

## 2. Build the APK

From this project folder (`24-7online`):

```bash
flutter pub get
flutter build apk --release
```

The APK will be at:

```
build/app/outputs/flutter-apk/app-release.apk
```

> Notes:
> - The Gradle wrapper jar and `android/local.properties` are **auto-generated**
>   by the Flutter tool on first build — you don't need to add them manually.
> - If you have **not** set up a release keystore yet, the release build is
>   automatically signed with the **debug key** so it installs immediately.
>   Set up a real keystore (next section) before publishing to the Play Store.

### Release signing (real keystore)

1. Generate a keystore (one time). `keytool` ships with your JDK 21:
   ```bash
   keytool -genkey -v -keystore android/upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   It will prompt for a keystore password, your name/org, etc. **Remember the
   password** — you cannot recover it.
2. Copy `android/key.properties.example` to `android/key.properties` and fill in
   the passwords / alias / `storeFile` you just used.
3. Rebuild:
   ```bash
   flutter build apk --release
   ```
   The build now signs with your release key. `key.properties` and `*.jks` are
   git-ignored, so your secrets stay out of version control. Keep a safe backup
   of the `.jks` file — losing it means you can't update the app on Play.

### Install on a phone

- Plug in the phone (USB debugging on) and run:
  ```bash
  flutter install
  ```
- Or copy `app-release.apk` to the phone and open it (allow "install from
  unknown sources").

### Run while developing

```bash
flutter run
```

---

## 3. Important on-device settings (for reliable background buzzing)

Android aggressively kills background apps. For the alarm to fire on time:

1. **Exact alarms** — On Android 12+ the app declares `USE_EXACT_ALARM`, which
   is allowed for alarm/timer apps, so no prompt is normally needed. If buzzing
   is late, check Settings → Apps → Vibrate Timer → *Alarms & reminders* = allowed.
2. **Battery optimization** — Set the app to **"Unrestricted" / "Don't
   optimize"** in Settings → Apps → Vibrate Timer → Battery. On Xiaomi/Oppo/
   Vivo/Samsung also enable **Autostart** and lock the app in recents.
3. Keep **Do Not Disturb** off (or allow the app), or vibration may be suppressed.

---

## 4. Project layout

```
lib/main.dart                     # All app logic + UI + background vibrate callback
pubspec.yaml                      # Dependencies
android/app/src/main/AndroidManifest.xml   # Permissions + alarm services
android/app/build.gradle          # minSdk 26, applicationId, signing
android/app/src/main/kotlin/.../MainActivity.kt
android/app/src/main/res/...      # Launcher icon (adaptive XML) + themes
```

### Packages used
- `android_alarm_manager_plus` — exact repeating background alarms (survives app kill / reboot)
- `vibration` — strong 3-second vibration (amplitude 255)
- `shared_preferences` — remembers running state + chosen interval

---

## 5. How it works (quick tour of `lib/main.dart`)

- `vibrateCallback()` is a top-level function marked `@pragma('vm:entry-point')`.
  `AndroidAlarmManager` runs it in a **separate background isolate** each time
  the alarm fires — this is why it works even when the UI/app isn't running.
- **Start** → `AndroidAlarmManager.periodic(Duration(minutes: n), kAlarmId,
  vibrateCallback, exact: true, wakeup: true, rescheduleOnReboot: true)`.
- **Stop** → `AndroidAlarmManager.cancel(kAlarmId)` + `Vibration.cancel()`.

To change the buzz length, edit `duration: 3000` (milliseconds) in
`vibrateCallback`.
