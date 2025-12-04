import 'dart:async';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'twilio_flutter_video_sdk_method_channel.dart';
import 'src/twilio_video_room.dart';

abstract class TwilioFlutterVideoSdkPlatform extends PlatformInterface {
  /// Constructs a TwilioFlutterVideoSdkPlatform.
  TwilioFlutterVideoSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static TwilioFlutterVideoSdkPlatform _instance = MethodChannelTwilioFlutterVideoSdk();

  /// The default instance of [TwilioFlutterVideoSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelTwilioFlutterVideoSdk].
  static TwilioFlutterVideoSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [TwilioFlutterVideoSdkPlatform] when
  /// they register themselves.
  static set instance(TwilioFlutterVideoSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Join a Twilio video room
  Future<void> joinRoom(RoomOptions options) {
    throw UnimplementedError('joinRoom() has not been implemented.');
  }

  /// Disconnect from the current room
  Future<void> disconnect() {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  /// Mute or unmute the microphone
  Future<void> setMuted(bool muted) {
    throw UnimplementedError('setMuted() has not been implemented.');
  }

  /// Enable or disable video
  Future<void> setVideoEnabled(bool enabled) {
    throw UnimplementedError('setVideoEnabled() has not been implemented.');
  }

  /// Switch between front and back camera
  Future<void> switchCamera() {
    throw UnimplementedError('switchCamera() has not been implemented.');
  }

  /// Get event stream for video events
  Stream<Map<dynamic, dynamic>> get events {
    throw UnimplementedError('events stream has not been implemented.');
  }
}
