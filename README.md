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

## Platform Support

- ✅ Android (API 24+)
- ✅ iOS (13.0+)

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
  twilio_flutter_video_sdk: ^0.0.1
```

### Android Setup

The plugin requires the following permissions in your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.INTERNET" />
```

The Twilio Video SDK dependency is automatically included.

### iOS Setup

Add the following permissions to your `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs access to the camera for video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to the microphone for video calls</string>
```

The Twilio Video SDK dependency is automatically included via CocoaPods.

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
  print('Event: $event');
});

room.errors.listen((error) {
  print('Error: $error');
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

### Complete Example

See the `example/` directory for a complete working example.

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

### RoomOptions

Configuration for joining a room.

```dart
RoomOptions(
  accessToken: 'YOUR_ACCESS_TOKEN',  // Required
  roomName: 'room-name',              // Required
  enableAudio: true,                  // Optional, default: true
  enableVideo: true,                  // Optional, default: true
  enableFrontCamera: true,            // Optional, default: true
  enableDominantSpeaker: false,       // Optional, default: false
  enableNetworkQuality: false,        // Optional, default: false
)
```

### TwilioVideoEvent

Enumeration of video events:

- `participantConnected`
- `participantDisconnected`
- `videoTrackAdded`
- `videoTrackRemoved`
- `audioTrackAdded`
- `audioTrackRemoved`
- `connectionFailure`
- `connected`
- `disconnected`
- `reconnecting`
- `reconnected`
- `dominantSpeakerChanged`

## Getting Access Tokens

To use this plugin, you need Twilio access tokens. You can generate them using the [Twilio Video Access Token Generator](https://www.twilio.com/docs/video/tutorials/user-identity-access-tokens) or by creating a backend service.

**Important**: Never embed your Twilio credentials in your mobile app. Always use a backend service to generate access tokens.

## Permissions

The plugin requires camera and microphone permissions. Make sure to request these permissions before joining a room:

```dart
import 'package:permission_handler/permission_handler.dart';

await [
  Permission.camera,
  Permission.microphone,
].request();
```

## Troubleshooting

### Android Issues

- Ensure minSdk is 24 or higher
- Check that all permissions are declared in AndroidManifest.xml
- Verify that Twilio Video SDK dependency is properly included

### iOS Issues

- Ensure iOS deployment target is 13.0 or higher
- Check that camera and microphone permissions are in Info.plist
- Run `pod install` in the iOS directory after adding the plugin

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Twilio Video SDK](https://www.twilio.com/docs/video) for the native SDKs
- Flutter team for the plugin architecture
