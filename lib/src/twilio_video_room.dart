import 'dart:async';
import '../twilio_flutter_video_sdk_platform_interface.dart';
import 'twilio_video_events.dart';

/// Configuration for joining a Twilio video room
class RoomOptions {
  /// Access token for authentication
  final String accessToken;

  /// Room name to join
  final String roomName;

  /// Enable audio by default
  final bool enableAudio;

  /// Enable video by default
  final bool enableVideo;

  /// Enable dominant speaker detection
  final bool enableDominantSpeaker;

  /// Enable network quality reporting
  final bool enableNetworkQuality;

  /// Use front camera by default
  final bool enableFrontCamera;

  RoomOptions({
    required this.accessToken,
    required this.roomName,
    this.enableAudio = true,
    this.enableVideo = true,
    this.enableDominantSpeaker = false,
    this.enableNetworkQuality = false,
    this.enableFrontCamera = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'accessToken': accessToken,
      'roomName': roomName,
      'enableAudio': enableAudio,
      'enableVideo': enableVideo,
      'enableDominantSpeaker': enableDominantSpeaker,
      'enableNetworkQuality': enableNetworkQuality,
      'enableFrontCamera': enableFrontCamera,
    };
  }
}

/// Controller for managing Twilio Video Room
class TwilioVideoRoom {
  final TwilioFlutterVideoSdkPlatform _platform;
  final StreamController<TwilioVideoEvent> _eventController =
      StreamController<TwilioVideoEvent>.broadcast();
  final StreamController<ParticipantInfo> _participantController =
      StreamController<ParticipantInfo>.broadcast();
  final StreamController<VideoTrackInfo> _videoTrackController =
      StreamController<VideoTrackInfo>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;

  TwilioVideoRoom(this._platform);

  /// Stream of video events
  Stream<TwilioVideoEvent> get events => _eventController.stream;

  /// Stream of participant updates
  Stream<ParticipantInfo> get participantEvents => _participantController.stream;

  /// Stream of video track updates
  Stream<VideoTrackInfo> get videoTrackEvents => _videoTrackController.stream;

  /// Stream of error messages
  Stream<String> get errors => _errorController.stream;

  /// Check if currently connected to a room
  bool get isConnected => _isConnected;

  /// Check if microphone is muted
  bool get isMuted => _isMuted;

  /// Check if video is enabled
  bool get isVideoEnabled => _isVideoEnabled;

  /// Check if using front camera
  bool get isFrontCamera => _isFrontCamera;

  /// Join a video room
  Future<void> joinRoom(RoomOptions options) async {
    try {
      await _platform.joinRoom(options);
      _isConnected = true;
    } catch (e) {
      _errorController.add(e.toString());
      rethrow;
    }
  }

  /// Disconnect from the current room
  Future<void> disconnect() async {
    try {
      await _platform.disconnect();
      _isConnected = false;
    } catch (e) {
      _errorController.add(e.toString());
      rethrow;
    }
  }

  /// Mute or unmute the microphone
  Future<void> setMuted(bool muted) async {
    try {
      await _platform.setMuted(muted);
      _isMuted = muted;
    } catch (e) {
      _errorController.add(e.toString());
      rethrow;
    }
  }

  /// Toggle mute state
  Future<void> toggleMute() async {
    await setMuted(!_isMuted);
  }

  /// Enable or disable video
  Future<void> setVideoEnabled(bool enabled) async {
    try {
      await _platform.setVideoEnabled(enabled);
      _isVideoEnabled = enabled;
    } catch (e) {
      _errorController.add(e.toString());
      rethrow;
    }
  }

  /// Toggle video on/off
  Future<void> toggleVideo() async {
    await setVideoEnabled(!_isVideoEnabled);
  }

  /// Switch between front and back camera
  Future<void> switchCamera() async {
    try {
      await _platform.switchCamera();
      _isFrontCamera = !_isFrontCamera;
    } catch (e) {
      _errorController.add(e.toString());
      rethrow;
    }
  }

  /// Handle event from platform
  void handleEvent(Map<dynamic, dynamic> event) {
    final eventType = event['event'] as String?;
    if (eventType == null) return;

    switch (eventType) {
      case 'participantConnected':
        _eventController.add(TwilioVideoEvent.participantConnected);
        if (event['participant'] != null) {
          _participantController.add(
              ParticipantInfo.fromMap(event['participant'] as Map));
        }
        break;
      case 'participantDisconnected':
        _eventController.add(TwilioVideoEvent.participantDisconnected);
        if (event['participant'] != null) {
          _participantController.add(
              ParticipantInfo.fromMap(event['participant'] as Map));
        }
        break;
      case 'videoTrackAdded':
        _eventController.add(TwilioVideoEvent.videoTrackAdded);
        if (event['track'] != null) {
          _videoTrackController.add(
              VideoTrackInfo.fromMap(event['track'] as Map));
        }
        break;
      case 'videoTrackRemoved':
        _eventController.add(TwilioVideoEvent.videoTrackRemoved);
        if (event['track'] != null) {
          _videoTrackController.add(
              VideoTrackInfo.fromMap(event['track'] as Map));
        }
        break;
      case 'audioTrackAdded':
        _eventController.add(TwilioVideoEvent.audioTrackAdded);
        break;
      case 'audioTrackRemoved':
        _eventController.add(TwilioVideoEvent.audioTrackRemoved);
        break;
      case 'connectionFailure':
        _eventController.add(TwilioVideoEvent.connectionFailure);
        if (event['error'] != null) {
          _errorController.add(event['error'] as String);
        }
        break;
      case 'connected':
        _eventController.add(TwilioVideoEvent.connected);
        _isConnected = true;
        break;
      case 'disconnected':
        _eventController.add(TwilioVideoEvent.disconnected);
        _isConnected = false;
        break;
      case 'reconnecting':
        _eventController.add(TwilioVideoEvent.reconnecting);
        break;
      case 'reconnected':
        _eventController.add(TwilioVideoEvent.reconnected);
        break;
      case 'dominantSpeakerChanged':
        _eventController.add(TwilioVideoEvent.dominantSpeakerChanged);
        break;
    }
  }

  /// Dispose resources
  void dispose() {
    _eventController.close();
    _participantController.close();
    _videoTrackController.close();
    _errorController.close();
  }
}

