import 'dart:async';
import '../twilio_flutter_video_sdk_platform_interface.dart';
import 'twilio_video_room.dart';

/// Main controller for Twilio Video SDK
class TwilioVideoController {
  final TwilioFlutterVideoSdkPlatform _platform;
  TwilioVideoRoom? _room;
  StreamSubscription<Map<dynamic, dynamic>>? _eventSubscription;

  TwilioVideoController() : _platform = TwilioFlutterVideoSdkPlatform.instance {
    _listenToEvents();
  }

  /// Get the current room instance
  TwilioVideoRoom? get room => _room;

  /// Listen to platform events
  void _listenToEvents() {
    _eventSubscription = _platform.events.listen((event) {
      _room?.handleEvent(event);
    }, onError: (error) {
      // Error will be handled through error stream from events
    });
  }

  /// Create a new video room instance
  TwilioVideoRoom createRoom() {
    _room?.dispose();
    _room = TwilioVideoRoom(_platform);
    return _room!;
  }

  /// Dispose resources
  void dispose() {
    _eventSubscription?.cancel();
    _room?.dispose();
    _room = null;
  }
}

/// Singleton instance for easy access
final twilioVideo = TwilioVideoController();

