# GitHub Actions Build and Android Signing

This folder contains CI workflows for BirdNET Live.

## Android Release Signing in CI

The Android job in [build.yml](build.yml) signs the release APK using GitHub secrets.

### Secrets Required

Create these repository secrets in GitHub:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_STORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

These names must match [build.yml](build.yml) exactly.

### 1) Create a Keystore (one-time)

Use an upload key for Play App Signing (recommended), not your final app-signing key.

```bash
keytool -genkeypair \
  -v \
  -storetype JKS \
  -keystore upload-keystore.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

If `keytool` is not found, install a JDK (Java 17+), then rerun.

### 2) Convert Keystore to Base64

Use one of the commands below and copy the full single-line output.

Linux:

```bash
base64 -w 0 upload-keystore.jks
```

macOS:

```bash
base64 upload-keystore.jks | tr -d '\n'
```

Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))
```

### 3) Add Secrets in GitHub UI

1. Open repository settings.
2. Go to `Settings > Secrets and variables > Actions`.
3. Select `New repository secret`.
4. Add each secret:
   - `ANDROID_KEYSTORE_BASE64`: base64 string from step 2
   - `ANDROID_STORE_PASSWORD`: keystore password
   - `ANDROID_KEY_ALIAS`: alias used in keytool (example: `upload`)
   - `ANDROID_KEY_PASSWORD`: key password for that alias

### 4) Optional: Add Secrets with GitHub CLI

```bash
gh secret set ANDROID_KEYSTORE_BASE64

gh secret set ANDROID_STORE_PASSWORD

gh secret set ANDROID_KEY_ALIAS

gh secret set ANDROID_KEY_PASSWORD
```

The CLI will prompt for each value.

### 5) How Signing Works in CI

During the Android build job:

1. The workflow decodes `ANDROID_KEYSTORE_BASE64` to `android/app/upload-keystore.jks`.
2. The workflow writes `android/key.properties` using the other three secrets.
3. `flutter build apk --release` uses `android/app/build.gradle`, which reads `key.properties`.
4. Temporary signing files are deleted at the end of the job.

### Security Notes

- Never commit `upload-keystore.jks` or `android/key.properties`.
- Limit who can edit repository secrets.
- Store a secure offline backup of your keystore.
- If this key is lost, app update publishing can be blocked.
