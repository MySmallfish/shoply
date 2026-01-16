# Shoply

Native iOS (SwiftUI) and Android (Jetpack Compose) shopping list app with Firebase Auth + Firestore realtime sync.

## Structure
- `ios/Shoply` - iOS app source files (SwiftUI)
- `android/` - Android app (Gradle + Compose)
- `firebase/` - Firestore rules + Cloud Functions
- `docs/architecture.md` - data model + core flows

## Firebase Setup
1. Create a Firebase project.
2. Enable Authentication providers:
   - Apple (iOS)
   - Google
3. Create a Firestore database (production or test mode).
4. Add apps:
   - iOS bundle ID: `com.shoply.app`
   - Android package: `com.shoply.app`
5. Download config files:
   - `GoogleService-Info.plist` -> `ios/Shoply`
   - `google-services.json` -> `android/app`

## iOS Setup (Xcode)
1. Open `ios/Shoply.xcodeproj`.
2. Replace `ios/Shoply/Resources/GoogleService-Info.plist` with the real Firebase file.
3. Update `ios/Shoply/Resources/Info.plist` URL types to match `REVERSED_CLIENT_ID`.
4. In Xcode, enable "Sign in with Apple" capability.
5. Build and run.

## Android Setup (Android Studio)
1. Open `android/` in Android Studio.
2. Replace `android/app/google-services.json` with the real Firebase file.
3. Update `default_web_client_id` in `android/app/src/main/res/values/strings.xml`.
4. Sync Gradle and run (wrapper is configured).

## Invites (Email Link)
Cloud Functions handle invite creation and acceptance.

From repo root:
```
cd firebase/functions
npm install
```

Set config and deploy:
```
firebase functions:config:set sendgrid.key="YOUR_KEY" sendgrid.from="no-reply@yourdomain.com" app.invite_url="https://yourdomain.com/invite"
firebase deploy --only functions
```

Notes:
- If SendGrid is not configured, `sendInvite` still returns an invite link.
- `acceptInvite` adds the signed-in user to the list using the token in the link.

## Deep Links (Invite URL)
The app expects invite links like `https://shoply.simplevision.co.il/invite?token=...`.

You need to host these files on your domain:
- iOS Universal Links (AASA): `https://shoply.simplevision.co.il/.well-known/apple-app-site-association`
- Android App Links: `https://shoply.simplevision.co.il/.well-known/assetlinks.json`

The app is already configured for the domain:
- iOS entitlements: `ios/Shoply/Resources/Shoply.entitlements`
- Android intent filter: `android/app/src/main/AndroidManifest.xml`
Sample files live in `docs/deeplinks/`.

## Auth Verification
Quick checks after enabling providers in Firebase:
- iOS: Sign in with Apple + Google both complete and return to the app.
- Android: Google sign-in completes without errors (debug SHA-1 is registered).

## Project Generation
- iOS project is generated with XcodeGen from `ios/project.yml`.

## Barcode Scanning
- iOS uses AVFoundation (camera permission required).
- Android uses CameraX + ML Kit (camera permission required).

## Next Steps
- Create a small web landing page at `app.invite_url` to handle install and deep links.
- Add push notifications for list changes.
