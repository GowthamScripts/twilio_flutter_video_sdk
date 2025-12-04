import 'package:flutter_test/flutter_test.dart';
import 'package:twilio_flutter_video_sdk/twilio_flutter_video_sdk.dart';
import 'package:twilio_flutter_video_sdk/twilio_flutter_video_sdk_platform_interface.dart';
import 'package:twilio_flutter_video_sdk/twilio_flutter_video_sdk_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockTwilioFlutterVideoSdkPlatform
    with MockPlatformInterfaceMixin
    implements TwilioFlutterVideoSdkPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final TwilioFlutterVideoSdkPlatform initialPlatform = TwilioFlutterVideoSdkPlatform.instance;

  test('$MethodChannelTwilioFlutterVideoSdk is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelTwilioFlutterVideoSdk>());
  });

  test('getPlatformVersion', () async {
    TwilioFlutterVideoSdk twilioFlutterVideoSdkPlugin = TwilioFlutterVideoSdk();
    MockTwilioFlutterVideoSdkPlatform fakePlatform = MockTwilioFlutterVideoSdkPlatform();
    TwilioFlutterVideoSdkPlatform.instance = fakePlatform;

    expect(await twilioFlutterVideoSdkPlugin.getPlatformVersion(), '42');
  });
}
