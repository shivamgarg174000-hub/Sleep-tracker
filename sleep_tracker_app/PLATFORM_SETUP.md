# Health Connect (Android) / HealthKit (iOS) — native setup

The `health` plugin needs real native permission declarations. The Dart code in
`health_service.dart` will silently fail permission requests without these.

## Android (Health Connect)
1. Minimum `minSdkVersion 26` in `android/app/build.gradle`.
2. Health Connect itself must be installed on the test device (Play Store) —
   on Android 14+ it ships with the OS; on 13 and below it's a separate app.
3. In `android/app/src/main/AndroidManifest.xml`, inside `<application>`:
   ```xml
   <uses-permission android:name="android.permission.health.READ_SLEEP" />
   <uses-permission android:name="android.permission.health.READ_STEPS" />
   <uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED" />
   <uses-permission android:name="android.permission.health.READ_TOTAL_CALORIES_BURNED" />

   <activity-alias
       android:name="ViewPermissionUsageActivity"
       android:exported="true"
       android:targetActivity=".MainActivity"
       android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
       <intent-filter>
           <action android:name="android.intent.action.VIEW_PERMISSION_USAGE" />
           <category android:name="android.intent.category.HEALTH_PERMISSIONS" />
       </intent-filter>
   </activity-alias>
   ```

## iOS (HealthKit)
1. In Xcode: target → Signing & Capabilities → **+ Capability → HealthKit**.
2. In `ios/Runner/Info.plist`, add:
   ```xml
   <key>NSHealthShareUsageDescription</key>
   <string>Kitty Sleep reads your sleep, step, and calorie data to power your dashboard and Kitty AI's guidance.</string>
   <key>NSHealthUpdateUsageDescription</key>
   <string>Kitty Sleep does not write health data, but iOS requires this key to be present.</string>
   ```
3. HealthKit is unavailable on the iOS Simulator for real data — test on a
   physical device with the Health app populated (e.g. via Apple Watch or
   manual entry).

Without these, `HealthService.requestPermissions()` returns `false` and the
app correctly falls back to the "Connect your wearable" empty state — it
will not crash, but it also won't be able to show real data until this is
done.

## Background audio (just_audio_background)

### Android
Add inside `<application>` in `AndroidManifest.xml`:
```xml
<service
    android:name="com.ryanheise.audioservice.AudioService"
    android:foregroundServiceType="mediaPlayback"
    android:exported="true">
    <intent-filter>
        <action android:name="android.media.browse.MediaBrowserService" />
    </intent-filter>
</service>
<receiver
    android:name="com.ryanheise.audioservice.MediaButtonReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.MEDIA_BUTTON" />
    </intent-filter>
</receiver>
```
And these permissions:
```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
```

### iOS
In Xcode: target → Signing & Capabilities → **+ Capability → Background Modes**
→ check **Audio, AirPlay, and Picture in Picture**.

## Soundscape audio files
`soundTrackCatalogProvider` (`lib/core/services/audio_providers.dart`) ships
with `REPLACE_WITH_YOUR_HOSTED_AUDIO_URL` placeholders instead of real URLs.
This is deliberate, not an oversight: white noise / rain / ambient tracks are
licensed audio content, and I can't bundle or link to a specific hosted
library on your behalf. To finish this:
1. Get properly licensed (or self-recorded/generated) loopable audio files.
2. Host them somewhere with a stable direct URL — Firebase Storage (already
   in your stack) works well: upload, then use `getDownloadURL()`.
3. Replace the `streamUrl`/`artUrl` placeholders in the catalog.
The playback engine (`AudioService`, lock-screen controls, sleep timer) is
fully wired and works immediately once real URLs are in place.

## Push notifications (FCM) + local bedtime reminders

### Android
No extra manifest work needed beyond what Firebase already requires — FCM
piggybacks on the `google-services.json` from `flutterfire configure`.
For Android 13+, `flutter_local_notifications`/`firebase_messaging` request
the `POST_NOTIFICATIONS` runtime permission automatically via
`NotificationService.requestPermission()`; no manual manifest entry needed
for that specific permission with recent plugin versions, but confirm your
installed plugin version's docs if `flutter pub get` pulls a newer major.

Add this so local notifications survive a device reboot with their schedule
intact:
```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

### iOS
1. Xcode: target → Signing & Capabilities → **+ Capability → Push Notifications**.
2. Also add **Background Modes → Remote notifications** (separate from the
   Audio background mode added earlier — check both).
3. Push notifications require a real Apple Developer account + APNs key
   uploaded to Firebase (**Firebase Console → Project settings → Cloud
   Messaging → Apple app configuration**). This does not work at all on the
   iOS Simulator — test on a physical device.

### Sending a push (server side)
`NotificationService` only handles the client half: permission, token
capture, and displaying a push that arrives. Actually **sending** one
requires server-side code — the client can never securely send pushes to
other devices. Minimal example via a Cloud Function, triggered whenever a
new `sleepSessions` doc is written:

```js
// functions/index.js
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore } = require("firebase-admin/firestore");

exports.notifyOnSleepSession = onDocumentCreated(
  "users/{uid}/sleepSessions/{sessionId}",
  async (event) => {
    const uid = event.params.uid;
    const userDoc = await getFirestore().doc(`users/${uid}`).get();
    const { fcmToken, pushNotificationsEnabled } = userDoc.data() || {};
    if (!pushNotificationsEnabled || !fcmToken) return;

    await getMessaging().send({
      token: fcmToken,
      notification: {
        title: "Sleep session logged 🌙",
        body: "Kitty AI has a fresh look at your night — check it out.",
      },
    });
  }
);
```
Deploy with `firebase deploy --only functions` once you've run
`firebase init functions` in the project root.
