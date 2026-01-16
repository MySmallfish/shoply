# Shoply Architecture

## Product Goals
- Shared shopping lists with realtime updates
- Fast, clean UI for daily use
- Barcode scan for quick add or mark bought
- Apple/Google login and email invites
- Offline support with seamless sync

## Data Model (Firestore)

### users/{uid}
- displayName
- email
- photoURL
- createdAt
- lastSeenAt
- lastListId

### lists/{listId}
- title
- createdAt
- createdBy
- updatedAt
- memberIds (array of uid)

### lists/{listId}/members/{uid}
- role (owner|editor|viewer)
- addedAt
- addedBy

### lists/{listId}/items/{itemId}
- name
- normalizedName
- barcode (optional)
- isBought
- createdAt
- createdBy
- updatedAt
- boughtAt (optional)
- boughtBy (optional)

### lists/{listId}/invites/{inviteId}
- email
- role
- token
- status (pending|accepted|revoked|expired)
- createdAt
- createdBy
- expiresAt

## Core Flows

### Auth
- iOS: Sign in with Apple + Google
- Android: Google sign-in
- On auth, create or update users/{uid}

### Lists
- Query lists where memberIds contains uid
- Keep last selected list in users/{uid}.lastListId
- Default list created on first sign-in ("Grocery")

### Items
- Listen to items subcollection (realtime)
- Tapping checkbox toggles isBought and sets boughtAt/boughtBy

### Barcode Scan
- If scanned barcode matches an item in list:
  - prompt to mark as bought
- If no match:
  - prompt to create item with optional name

### Invites
- Generate invite token and store in invites subcollection
- Cloud Function sends email with invite link
- App can accept invite via deep link or manual token entry

## Offline
- Firestore offline persistence enabled on both platforms
- Optimistic UI updates; conflicts resolved by last write
