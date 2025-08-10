# puffpoint (MVP)

Stack: Flutter (Android+iOS), Riverpod, GoRouter, flutter_map (OSM), Firebase (Auth, Firestore, Storage, Functions, App Check).

## Setup
1. Flutter stable installed
2. Firebase project (dev): create project `puffpoint-dev`
3. Run:
   - `dart pub global activate flutterfire_cli`
   - `flutterfire configure --project=puffpoint-dev` (Android+iOS). This overwrites `lib/firebase_options.dart`.
   - Enable providers: Auth (Anonymous), Firestore, Storage, Functions, App Check (Debug). 
4. Deploy backend (optional for emulator):
   - `cd firebase/functions && npm i && npm run build`
   - `firebase deploy --only functions` or `firebase emulators:start`
5. Firestore rules: deploy `firebase/firestore.rules` or via console.

## Run
```
flutter run
```

### Run with Firebase Emulator Suite
```
flutter run \
  --dart-define=USE_EMULATORS=true \
  --dart-define=FUNCTIONS_PORT=5001
```
- Auth: 9099, Firestore: 8080, Storage: 9199, Functions: 5001 (override via `FUNCTIONS_PORT`).

## Features
- Map: OSM tiles, attribution, marker clustering, center on location (fallback Berlin)
- Seed 3 spots in Berlin
- Spot bottom sheet: title, rating, buttons Route/Review + Photo upload
- Create spot form
- Reviews update avgRating/ratingsCount (transaction)
- Photo upload to tmp/ -> creates pending moderation doc
- Admin screen: pending photos approve/reject (now copies file, creates thumbnail, updates doc)
- Admin screen: roles tab to grant/revoke `admin`/`mod` via callable `setRole`
- Nominatim proxy via Cloud Function `nominatimSearch`

## Notes
- Replace `firebase_options.dart` with generated file.
- Add App Check debug if needed.
- Security rules in `firebase/firestore.rules` implement MVP constraints.
