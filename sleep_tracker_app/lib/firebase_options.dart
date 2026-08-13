// This file is a placeholder. Real Firebase config is machine-generated —
// it must NOT be hand-written, or Auth/Firestore will fail silently on
// device with cryptic errors.
//
// To generate it for real:
//   1. dart pub global activate flutterfire_cli
//   2. flutterfire configure
//      (select/create your Firebase project, tick Android + iOS)
// This overwrites this file with real `DefaultFirebaseOptions.currentPlatform`
// values for each platform. Do not edit the generated file by hand.
//
// Until you run that command, the app will build but Firebase.initializeApp()
// in main.dart will throw — that's expected and intentional; it's the
// signal that this step hasn't been done yet, rather than a silent no-op.

import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'DefaultFirebaseOptions has not been configured yet. '
      'Run `flutterfire configure` from the project root to generate real values.',
    );
  }
}
