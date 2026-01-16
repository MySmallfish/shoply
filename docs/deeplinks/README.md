# Deep Link Hosting

Place these files on your domain:
- `/.well-known/apple-app-site-association`
- `/.well-known/assetlinks.json`

## iOS (AASA)
Update `TEAMID` with your Apple Developer Team ID.

## Android (assetlinks)
Replace `REPLACE_WITH_SHA256` with your app signing SHA-256 fingerprint.

For debug builds (local testing), you can get SHA-256 with:
```
/opt/homebrew/opt/openjdk@17/bin/keytool -list -v \
  -alias androiddebugkey \
  -keystore ~/.android/debug.keystore \
  -storepass android -keypass android | rg SHA256
```
