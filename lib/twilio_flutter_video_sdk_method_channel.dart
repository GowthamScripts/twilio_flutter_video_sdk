import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'twilio_flutter_video_sdk_platform_interface.dart';
import 'src/twilio_video_room.dart';

/// An implementation of [TwilioFlutterVideoSdkPlatform] that uses method channels.
class MethodChannelTwilioFlutterVideoSdk extends TwilioFlutterVideoSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('twilio_flutter_video_sdk');

  /// The event channel used to receive events from the native platform.
  @visibleForTesting
  final eventChannel = const EventChannel('twilio_flutter_video_sdk_events');

  Stream<Map<dynamic, dynamic>>? _events;

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> joinRoom(RoomOptions options) async {
    await methodChannel.invokeMethod<void>('joinRoom', options.toMap());
  }

  @override
  Future<void> disconnect() async {
    await methodChannel.invokeMethod<void>('disconnect');
  }

  @override
  Future<void> setMuted(bool muted) async {
    await methodChannel.invokeMethod<void>('setMuted', {'muted': muted});
  }

  @override
  Future<void> setVideoEnabled(bool enabled) async {
    await methodChannel.invokeMethod<void>('setVideoEnabled', {'enabled': enabled});
  }

  @override
  Future<void> switchCamera() async {
    await methodChannel.invokeMethod<void>('switchCamera');
  }

  @override
  Stream<Map<dynamic, dynamic>> get events {
    _events ??= eventChannel.receiveBroadcastStream().map((dynamic event) {
      if (event is Map) {
        return event.cast<dynamic, dynamic>();
      }
      return <dynamic, dynamic>{};
    });
    return _events!;
  }
}
