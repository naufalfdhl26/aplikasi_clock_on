# aplikasi_clockon

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

## Backend & Setup Notes

- This app integrates with the GoCloud REST API (api.247go.app/v5) using the DataService wrapper at `lib/restapi.dart`.
- Firebase is used for authentication; Firebase options are in `lib/firebase_options.dart`. Ensure `google-services.json` / `GoogleService-Info.plist` are configured for Android/iOS.
- The admin console is hosted on https://console.247go.app; the mobile app uses GoCloud APIs at https://api.247go.app/v5, and the ClockOn service at https://clockon.247go.app/. Adjust `lib/config.dart` if you need to point to a different API base URL.
- Wi-Fi detection uses `network_info_plus`. On Android, request `ACCESS_FINE_LOCATION` and `ACCESS_WIFI_STATE`; on iOS set `NSLocationWhenInUseUsageDescription` in Info.plist.
- The app uses Firebase Auth and then maps the user email to the employee/admin record using the remote API.

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
