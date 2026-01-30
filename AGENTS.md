# Shoply Agent Handoff

This file captures current project state, key decisions, build steps, and known issues so the next agent can continue without re-discovery.

## Project Overview
- Native iOS (SwiftUI) + native Android (Kotlin/Jetpack Compose) shopping list app.
- Firebase backend (Auth, Firestore, Functions).
- Features: shared lists, real-time updates, barcode scanning, invites, list switching, role-based members.
- iOS/Android both target simple, clean UI.

## Git Workflow (Important)
- Repo remote: `git@github.com:MySmallfish/shoply.git` (branch: `main`).
- Commit after every change (small, descriptive commits).
- Push to `origin` only when explicitly requested by the user.
- Open PRs only when explicitly requested by the user.
- Never commit secrets (see Firebase notes below).

## Current Status (As Of Last Change)
- iOS scaling issue fixed by restoring launch screen config.
- Pull-to-refresh added on iOS and Android.
- "Enter/Done" on item text field triggers Add (same as plus button) on iOS and Android.
- Default "Grocery" list created at startup if missing; it becomes current list.
- Items now use quantity-based flow (no checklist UI). Quantities can go negative; list sorted by quantity left to buy.
- Tapping an item opens a "How much did you buy?" dialog with Bought/Need toggle; +/- still adjust quantity by 1.
- Barcode scan of an existing item opens the adjust dialog; otherwise prompt to add item details.
- iOS Google Sign-In URL scheme restored in Info.plist.
- Invites now write directly to Firestore only (no email or push); on success the app opens the system share sheet with an invite link.
- Invite docs include `emailLower`, `allowedEmails`, `creatorName`, and `creatorEmail` for compatibility.
- Pending invitations are read from top-level `invitesInbox` (filtered by `emailLower`) so invitees see invites across all lists.
- If an invited list name matches an existing list, the user is prompted to merge or keep separate; keeping separate renames to `[listName] - [creator]`, merging removes the duplicate list.
- Android invite send now surfaces errors when list/user/email is missing; FirebaseFunctions is used for acceptInvite.
- Android shows a toast if acceptInvite fails (see `inviteActionError` flow).

## Key Files and Responsibilities
### iOS
- `ios/Shoply/App/ShoplyApp.swift`
  - Root entry; dynamic type clamp removed to keep default scaling.
- `ios/Shoply/Resources/Info.plist`
  - `UILaunchStoryboardName` must be present to avoid iOS compatibility scaling.
  - `CFBundleURLTypes` includes Google reversed client ID.
- `ios/Shoply/Views/MainListView.swift`
  - Header, list, empty state, `refreshable` + overlay empty state.
- `ios/Shoply/Views/AddItemBar.swift`
  - Add bar UI; Return/Done triggers add.
- `ios/Shoply/ViewModels/ListViewModel.swift`
  - `refresh()` rebinds listener without clearing items.
- `ios/Shoply/Views/ScannerView.swift`
  - `videoGravity = .resizeAspect` to avoid zoomed camera.
- `ios/Shoply/Views/PendingInvitesView.swift`
  - Pending invites list + Accept button.
- `ios/Shoply/Views/ShareSheet.swift`
  - Wrapper for the iOS share sheet used to send invite links.
- `ios/Shoply/Services/PushTokenStore.swift`
  - Stores FCM tokens under `/users/{uid}/tokens/{token}`.

### Android
- `android/app/src/main/java/com/shoply/app/ShoplyApp.kt`
  - Compose screens, pull-to-refresh, Add item bar (IME Done triggers add), and invite link sharing.
- `android/app/src/main/java/com/shoply/app/MainViewModel.kt`
  - `refreshSelectedList()` rebinds item listener, invite accept flow handles merge prompt on name conflicts.
- `android/app/build.gradle`
  - `androidx.compose.material:material` added for pull-to-refresh.
- `android/app/src/main/java/com/shoply/app/ScannerView.kt`
  - PreviewView scale set to FIT_CENTER.
- `android/app/src/main/java/com/shoply/app/ShoplyMessagingService.kt`
  - FCM service + notification display.
- `android/app/src/main/java/com/shoply/app/PushTokenStore.kt`
  - Stores FCM tokens under `/users/{uid}/tokens/{token}`.

## Build and Run (Local)
### iOS (Simulator)
Requires escalated permissions in this environment due to CoreSimulator and cache access.
```
xcodebuild -project ios/Shoply.xcodeproj \
  -scheme Shoply \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath ios/build/DerivedData \
  -clonedSourcePackagesDirPath ios/build/SourcePackages \
  -disableAutomaticPackageResolution \
  build
```
Install/launch:
```
xcrun simctl install 42E8C2C9-8425-4F06-98C6-7C10561B863B ios/build/DerivedData/Build/Products/Debug-iphonesimulator/Shoply.app
xcrun simctl launch 42E8C2C9-8425-4F06-98C6-7C10561B863B com.shoply.app
```
Active iPhone simulator used:
- iPhone 17 Pro UDID: `42E8C2C9-8425-4F06-98C6-7C10561B863B`

### Android (Emulator)
Android SDK path on this machine:
- `/opt/homebrew/share/android-commandlinetools`
- `adb` lives at `/opt/homebrew/share/android-commandlinetools/platform-tools/adb`

Local Gradle config:
- `android/local.properties` includes `sdk.dir=/opt/homebrew/share/android-commandlinetools`

If Gradle cannot find Java, set:
```
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
```
If SDK path is not detected, set:
```
export ANDROID_SDK_ROOT="/opt/homebrew/share/android-commandlinetools"
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
```
```
./gradlew :app:installDebug
```
AVD used earlier: `RedoxApi35`.

## Firebase Notes (Do Not Commit Secrets)
- Firebase project configured; auth uses Google and email link.
- Firestore rules adjusted to allow list owner create member doc.
- `google-services.json` and `GoogleService-Info.plist` are stored in Dropbox:
  `/Users/yair/Library/CloudStorage/Dropbox/Dev`
- Do not paste or commit API keys, tokens, or secrets.
- Firebase project/app identifiers:
  - Project: `shoply-il`
  - App: `shoply-il-app`
  - Region: `eur3`
- Auth methods (configured in Firebase Console):
  - Google Sign-In
  - Email link
- Invite URL base: `https://shoply.simplevision.co.il/invite`
- Email sender: `shoply@doc.redox.co.il`
- Firebase Console URLs:
  - Project overview: `https://console.firebase.google.com/project/shoply-il/overview`
  - Auth providers: `https://console.firebase.google.com/project/shoply-il/authentication/providers`
  - Firestore: `https://console.firebase.google.com/project/shoply-il/firestore`
  - Functions: `https://console.firebase.google.com/project/shoply-il/functions`
- Functions build uses Node 20 (TypeScript will fail with older Node):
  - `PATH="/opt/homebrew/opt/node@20/bin:$PATH" npm --prefix firebase/functions run build`

## UI/UX Decisions (Current)
### iOS
- Custom header (list dropdown left, member/invite/scan/menu icons right).
- Background: `systemGroupedBackground`.
- List: `.plain` style; single section sorted by quantity; empty state overlays the list to keep pull-to-refresh.
- Add bar pinned in `safeAreaInset` with rounded text field + circular plus.
- Scanner view uses `.resizeAspect` to avoid zoomed camera preview.

### Android
- Material3 `TopAppBar` with list dropdown + actions.
- `LazyColumn` with single list sorted by quantity; item tap opens adjust dialog.
- Bottom add bar with TextField + plus button; IME Done triggers add.
- FloatingActionButton triggers scanner.
- Pull-to-refresh indicator at top center.
- Pending invitations dialog opened from the email icon in the top app bar.

## Known Issues / Things to Re-Verify
- Invite flow end-to-end: send invite -> accept -> member appears.
- Add item from input and via barcode scan; scan should prompt to mark as bought when matched.
- Google Sign-In crash on iOS if URL scheme missing; ensure `CFBundleURLSchemes` stays in `ios/Shoply/Resources/Info.plist`.
- If iOS rendering appears letterboxed again, re-check `UILaunchStoryboardName`.
- iPad UI was requested to ignore for now. `ios/project.yml` currently has `TARGETED_DEVICE_FAMILY: "1,2"`; change to `"1"` and run `xcodegen` if you want iPhone-only.
- If pull-to-refresh feels too short, adjust the `delay(350)` in Android or remove for immediate stop.
- Push notifications require APNs setup in Firebase + Push Notifications capability on the Apple developer portal.

## Deployment / Release Notes
- Firestore rules updated to allow list creator to add their own member doc.
- Firestore rules updated to allow invitees to read pending invites and users to store FCM tokens.
- Firestore rules updated to allow `invitesInbox` reads by matching `emailLower` and writes by list editors.
- Firestore indexes added for `invites` collectionGroup (status+allowedEmails, status+emailLower/email, status+token).
- Functions updated to create invite (unused by clients) and accept invite (used by clients), and to sync `invitesInbox`.
- Deploy rules + functions + indexes (requires Firebase CLI, network access, Node 20):
  - `PATH="/opt/homebrew/opt/node@20/bin:$PATH" firebase deploy --only firestore:rules,functions,firestore:indexes`
  - Project used: `shoply-il-app`
- If functions deploy fails with Node version errors, ensure Node 20+ in PATH as above.
- Firebase CLI warnings seen:
  - `firebase-functions` is outdated; consider upgrading to latest in `firebase/functions`.
  - `functions.config()` is deprecated; migrate to `params` before March 2026.
- Never commit secrets (e.g., SendGrid API key); store in Firebase Functions config or other secure store.

## Suggested Next Checks
1. Verify iOS and Android pull-to-refresh shows spinner and does not reset list state.
2. Verify Enter/Done on keyboard triggers add and clears input.
3. Test invite lifecycle (send invite -> accept -> member appears).
4. Test barcode scan -> adjust dialog for existing item.
