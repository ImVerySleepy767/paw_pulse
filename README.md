# PawPulse 🐾 — AI Pet Health Tracker

PawPulse is a cross-platform Flutter app that helps pet owners log their pets' daily health, spot trends, and get quick AI-powered answers — from "is this food safe for my dog?" to "where's the nearest vet?".

> Built for the *Mobile App Development* module (CIT2C18), Diploma in Applied AI, Temasek Polytechnic (2026). Received a NETS Certificate of Achievement for the NETS QR payment integration.

<!-- Add screenshots to docs/ and uncomment:
<p align="center">
  <img src="docs/home.png" width="220">
  <img src="docs/ai_assistant.png" width="220">
  <img src="docs/nearby_vets.png" width="220">
</p>
-->

## Features

**AI (Google Gemini)**
- **AI Assistant** — chat with a pet-care assistant for everyday health questions
- **Pet-Safe Scanner** — snap or scan a food/product and check whether it's safe for your pet
- **Food Calorie Estimator** — estimate calories from a photo of your pet's meal

**Health tracking**
- Daily health logs (create, edit, delete) stored in Cloud Firestore
- Calendar view of logged days with photos
- Insights screen with filters to spot trends per pet
- Local reminder notifications

**Location & community**
- **Nearby Vets** — finds clinics around you via OpenStreetMap / Overpass API, with fallback servers for reliability
- Pet Feed — share photo posts with other owners
- Trainer packages with live SGD currency conversion (open.er-api.com)

**Payments & security**
- **NETS QR payments** (sandbox) for premium trainer packages
- Firebase Auth: email/password with verification, Google Sign-In, and phone OTP
- Biometric app lock (fingerprint / face)
- Offline banner when the device loses connectivity; light/dark theme

## Tech stack
| Area | Tools |
|---|---|
| Framework | Flutter, Dart |
| State management | Riverpod 3 |
| Backend | Firebase Auth, Cloud Firestore |
| AI | Google Gemini API (`google_generative_ai`) |
| Maps & location | flutter_map, OpenStreetMap, Overpass API, geolocator |
| Payments | NETS OPENAPIPASS sandbox (QR) |
| Device features | mobile_scanner, image_picker, local_auth, flutter_local_notifications, connectivity_plus |

## Project structure
```
lib/
  config/      API configuration (example files only — see setup)
  models/      Data models (Firestore user, pet posts, NETS results)
  providers/   Riverpod providers (auth, connectivity, theme, NETS, ...)
  screens/     One file per screen
  services/    Firebase, NETS, vet locator, exchange rate, notifications
  widgets/     Reusable UI components
```

## Running it locally
API keys are **not** committed. To run the app:

1. Install Flutter and run `flutter pub get`.
2. Create a Firebase project, then run `flutterfire configure` to generate `lib/firebase_options.dart` and `android/app/google-services.json`.
3. Copy the example config files and add your own keys:
   ```
   lib/config/gemini_config.example.dart  ->  lib/config/gemini_config.dart
   lib/config/nets_config.example.dart    ->  lib/config/nets_config.dart
   ```
4. `flutter run`

## What I learned
- Structuring a larger Flutter app with Riverpod and a clear screens / services / providers split
- Keeping secrets out of source control with gitignored config files
- Third-party sandbox APIs can behave differently from production — the NETS sandbox only accepts specific provisioned transaction IDs
- Building resilience into network features, e.g. multiple Overpass API fallback servers for the vet locator