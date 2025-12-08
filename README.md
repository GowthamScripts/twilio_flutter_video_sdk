# Twilio Flutter Video SDK

A Flutter plugin for integrating Twilio Programmable Video SDK, providing video conferencing capabilities with features like mute/unmute, camera switching, video toggle, and meeting management.

## Features

- ✅ Join/Leave video rooms
- ✅ Mute/Unmute audio
- ✅ Toggle video on/off
- ✅ Switch between front and back camera
- ✅ End meeting/disconnect
- ✅ Real-time participant events
- ✅ Connection status monitoring
- ✅ Error handling
- ✅ Native video rendering via PlatformView
- ✅ Multiple remote participant support
- ✅ Video track enabled/disabled handling
- ✅ Automatic handling of existing participants when joining rooms

## Platform Support

- ✅ Android (API 24+, Twilio Video SDK 7.9.1)
- ✅ iOS (13.0+, Twilio Video SDK 5.3.0)

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  twilio_flutter_video_sdk:
    path: ../twilio_flutter_video_sdk
```

Or if published:

```yaml
dependencies:
  twilio_flutter_video_sdk: ^1.0.0
```

### Android Setup

The plugin requires the following permissions in your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.BLUETOOTH" />
```

The Twilio Video SDK dependency (version 7.9.1) is automatically included via Maven Central.

### iOS Setup

Add the following permissions to your `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs access to the camera for video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to the microphone for video calls</string>
<key>io.flutter.embedded_views_preview</key>
<true/>
```

The Twilio Video SDK dependency (version 5.3.0) is automatically included via CocoaPods.

Run `pod install` in the `ios/` directory after adding the plugin.

## Usage

### Basic Example

```dart
import 'package:twilio_flutter_video_sdk/twilio_flutter_video_sdk.dart';
import 'package:permission_handler/permission_handler.dart';

// Request permissions
await [Permission.camera, Permission.microphone].request();

// Create video controller
final videoController = TwilioVideoController();

// Create a room instance
final room = videoController.createRoom();

// Listen to events
room.events.listen((event) {
  print('Event: ${event.event}');
  if (event.event == 'connected') {
    print('Connected to room: ${event.data['roomName']}');
  }
});

room.errors.listen((error) {
  print('Error: $error');
});

// Listen to participant events
room.participantEvents.listen((participant) {
  print('Participant: ${participant.identity} ${participant.isConnected ? "connected" : "disconnected"}');
});

// Listen to video track events
room.videoTrackEvents.listen((track) {
  print('Video track: ${track.participantSid}, enabled: ${track.isEnabled}');
});

// Join a room
await room.joinRoom(
  RoomOptions(
    accessToken: 'YOUR_ACCESS_TOKEN',
    roomName: 'my-room',
    enableAudio: true,
    enableVideo: true,
    enableFrontCamera: true,
  ),
);

// Mute/Unmute
await room.toggleMute();

// Toggle video
await room.toggleVideo();

// Switch camera
await room.switchCamera();

// Disconnect
await room.disconnect();
```

### Displaying Video Views

The plugin provides `TwilioVideoView` widget for rendering native video:

```dart
import 'package:twilio_flutter_video_sdk/twilio_flutter_video_sdk.dart';

// Local video view (viewId: 0)
TwilioVideoView(viewId: 0)

// Remote participant video view (viewId: participantSid)
TwilioVideoView(viewId: participantSid)
```

### Complete Example with Video Views

```dart
class VideoRoomScreen extends StatefulWidget {
  @override
  _VideoRoomScreenState createState() => _VideoRoomScreenState();
}

class _VideoRoomScreenState extends State<VideoRoomScreen> {
  TwilioVideoController? _controller;
  TwilioVideoRoom? _room;
  Set<String> _remoteParticipantSids = {};
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _controller = TwilioVideoController();
    _room = _controller!.createRoom();
    
    // Listen to video track events
    _room!.videoTrackEvents.listen((track) {
      setState(() {
        if (track.isEnabled && track.nativeViewReady) {
          _remoteParticipantSids.add(track.participantSid);
        } else {
          _remoteParticipantSids.remove(track.participantSid);
        }
      });
    });
    
    // Listen to connection events
    _room!.events.listen((event) {
      if (event.event == 'connected') {
        setState(() => _isConnected = true);
      } else if (event.event == 'disconnected') {
        setState(() {
          _isConnected = false;
          _remoteParticipantSids.clear();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Local video
          SizedBox(
            height: 200,
            child: TwilioVideoView(viewId: 0),
          ),
          
          // Remote videos
          Expanded(
            child: _remoteParticipantSids.isEmpty
                ? Center(child: Text('Waiting for participants...'))
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                    ),
                    itemCount: _remoteParticipantSids.length,
                    itemBuilder: (context, index) {
                      final participantSid = _remoteParticipantSids.elementAt(index);
                      return TwilioVideoView(viewId: participantSid);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _room?.disconnect();
    _controller?.dispose();
    super.dispose();
  }
}
```

### Complete Example

See the `example/` directory for a complete working example with UI.

## API Reference

### TwilioVideoController

Main controller for managing video rooms.

```dart
final controller = TwilioVideoController();
final room = controller.createRoom();
controller.dispose(); // Clean up resources
```

### TwilioVideoRoom

Represents a video room connection.

#### Methods

- `Future<void> joinRoom(RoomOptions options)` - Join a video room
- `Future<void> disconnect()` - Disconnect from the room
- `Future<void> setMuted(bool muted)` - Mute or unmute audio
- `Future<void> toggleMute()` - Toggle mute state
- `Future<void> setVideoEnabled(bool enabled)` - Enable or disable video
- `Future<void> toggleVideo()` - Toggle video on/off
- `Future<void> switchCamera()` - Switch between front and back camera
- `void dispose()` - Dispose resources

#### Properties

- `bool isConnected` - Whether currently connected
- `bool isMuted` - Whether audio is muted
- `bool isVideoEnabled` - Whether video is enabled
- `bool isFrontCamera` - Whether using front camera

#### Streams

- `Stream<TwilioVideoEvent> events` - Video events stream
- `Stream<ParticipantInfo> participantEvents` - Participant updates
- `Stream<VideoTrackInfo> videoTrackEvents` - Video track updates
- `Stream<String> errors` - Error messages

### TwilioVideoView

Widget for displaying native video views.

```dart
TwilioVideoView({
  required String viewId,  // "0" for local, participantSid for remote
})
```

**Important Notes:**
- Local video always uses `viewId: "0"`
- Remote participant videos use `viewId: participantSid`
- Only create `TwilioVideoView` widgets when `track.isEnabled && track.nativeViewReady` is true
- The widget automatically handles platform-specific rendering (AndroidView on Android, UiKitView on iOS)

### RoomOptions

Configuration for joining a room.

```dart
RoomOptions(
  accessToken: 'YOUR_ACCESS_TOKEN',  // Required
  roomName: 'room-name',              // Required
  enableAudio: true,                  // Optional, default: true
  enableVideo: true,                  // Optional, default: true
  enableFrontCamera: true,            // Optional, default: true
)
```

### TwilioVideoEvent

Video events emitted by the room.

```dart
class TwilioVideoEvent {
  final String event;
  final Map<String, dynamic> data;
}
```

Event types:
- `connected` - Successfully connected to room
- `disconnected` - Disconnected from room
- `connectionFailure` - Failed to connect
- `participantConnected` - Remote participant joined
- `participantDisconnected` - Remote participant left
- `videoTrackAdded` - Video track added (local or remote)
- `videoTrackRemoved` - Video track removed
- `audioTrackAdded` - Audio track added
- `audioTrackRemoved` - Audio track removed

### VideoTrackInfo

Information about a video track.

```dart
class VideoTrackInfo {
  final String trackSid;
  final String participantSid;
  final bool isEnabled;
  final bool nativeViewReady;  // Whether native VideoView is ready
}
```

**Important:** Only create `TwilioVideoView` widgets when both `isEnabled` and `nativeViewReady` are `true`. This ensures the native view exists before Flutter tries to access it.

### ParticipantInfo

Information about a participant.

```dart
class ParticipantInfo {
  final String sid;
  final String identity;
  final bool isAudioEnabled;
  final bool isVideoEnabled;
  final bool isConnected;
}
```

## Video Track Lifecycle

The plugin handles video tracks as follows:

1. **When a participant joins with video:**
   - `videoTrackAdded` event is sent with `isEnabled: true` and `nativeViewReady: true`
   - Create `TwilioVideoView` widget with the participant's SID

2. **When a participant disables video:**
   - `videoTrackAdded` event is sent with `isEnabled: false`
   - Remove the participant from your UI or show a placeholder
   - The native view is kept for reuse when video is enabled again

3. **When a participant enables video again:**
   - `videoTrackAdded` event is sent with `isEnabled: true` and `nativeViewReady: true`
   - Re-add the participant to your UI

4. **When a participant leaves:**
   - `videoTrackRemoved` event is sent
   - Remove the participant from your UI

## Handling Existing Participants

When you join a room where other participants are already present:

- The plugin automatically detects existing participants
- Video tracks for existing participants are handled automatically
- `videoTrackAdded` events are sent for all existing subscribed tracks
- No special handling needed - just listen to `videoTrackEvents` and create views as tracks are added

## Getting Access Tokens

To use this plugin, you need Twilio access tokens. You can generate them using the [Twilio Video Access Token Generator](https://www.twilio.com/docs/video/tutorials/user-identity-access-tokens) or by creating a backend service.

**Important**: Never embed your Twilio credentials in your mobile app. Always use a backend service to generate access tokens.

Example backend endpoint (Node.js):

```javascript
const express = require('express');
const twilio = require('twilio');

const app = express();
const AccessToken = twilio.jwt.AccessToken;
const VideoGrant = AccessToken.VideoGrant;

app.post('/token', (req, res) => {
  const { identity, roomName } = req.body;
  
  const token = new AccessToken(
    process.env.TWILIO_ACCOUNT_SID,
    process.env.TWILIO_API_KEY,
    process.env.TWILIO_API_SECRET,
    { identity }
  );
  
  const videoGrant = new VideoGrant({ room: roomName });
  token.addGrant(videoGrant);
  
  res.json({ token: token.toJwt() });
});
```

## Permissions

The plugin requires camera and microphone permissions. Make sure to request these permissions before joining a room:

```dart
import 'package:permission_handler/permission_handler.dart';

final statuses = await [
  Permission.camera,
  Permission.microphone,
].request();

if (statuses[Permission.camera]?.isGranted == true &&
    statuses[Permission.microphone]?.isGranted == true) {
  // Permissions granted, proceed to join room
} else {
  // Handle permission denial
}
```

## Troubleshooting

### Android Issues

- **Build errors with Twilio SDK:**
  - Ensure `mavenCentral()` is in your `settings.gradle.kts` repositories
  - Verify Twilio Video SDK version 7.9.1 is being used
  - Clean and rebuild: `./gradlew clean build`

- **Camera not working:**
  - Ensure minSdk is 24 or higher
  - Check that all permissions are declared in AndroidManifest.xml
  - Verify camera permission is granted before joining room

- **Video views not showing:**
  - Ensure you're only creating `TwilioVideoView` when `nativeViewReady` is true
  - Check that `viewId` matches the participant SID for remote videos
  - Verify PlatformView is properly registered

### iOS Issues

- **Build errors:**
  - Ensure iOS deployment target is 13.0 or higher
  - Run `pod install` in the iOS directory after adding the plugin
  - Clean build folder in Xcode: Product → Clean Build Folder

- **Camera/Microphone not working:**
  - Check that camera and microphone permissions are in Info.plist
  - Verify `io.flutter.embedded_views_preview` is set to `true` in Info.plist
  - Request permissions before joining room

- **Video views not showing:**
  - Ensure you're only creating `TwilioVideoView` when `nativeViewReady` is true
  - Check that `viewId` matches the participant SID for remote videos
  - Verify PlatformView factory is properly registered

### Common Issues

- **"Waiting for video..." message:**
  - This appears when Flutter tries to create a PlatformView before the native view is ready
  - Solution: Only create `TwilioVideoView` when `track.nativeViewReady` is `true`

- **Frozen video when participant turns off video:**
  - Fixed in version 1.0.0: The plugin now properly removes renderers when video is disabled
  - Ensure you're handling `isEnabled: false` events and hiding/showing placeholders

- **Remote videos not appearing when joining active room:**
  - Fixed in version 1.0.0: The plugin automatically detects and handles existing participants
  - Just listen to `videoTrackEvents` and create views as tracks are added

## Version History

### 1.0.0+1
- Initial release
- Support for Android (SDK 7.9.1) and iOS (SDK 5.3.0)
- Native video rendering via PlatformView
- Multiple remote participant support
- Video track enabled/disabled handling
- Automatic handling of existing participants
- Proper cleanup when video is disabled (prevents frozen frames)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Twilio Video SDK](https://www.twilio.com/docs/video) for the native SDKs
- Flutter team for the plugin architecture
