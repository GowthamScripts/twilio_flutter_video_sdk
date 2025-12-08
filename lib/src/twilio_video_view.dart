import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget for rendering Twilio video views using PlatformView
/// 
/// viewId: 0 for local video, or participant SID for remote videos
class TwilioVideoView extends StatelessWidget {
  final String viewId;
  final double? width;
  final double? height;

  const TwilioVideoView({
    super.key,
    required this.viewId,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return SizedBox(
        width: width,
        height: height,
        child: AndroidView(
          viewType: 'twilio_video_view',
          layoutDirection: TextDirection.ltr,
          creationParams: <String, dynamic>{
            'viewId': viewId,
          },
          creationParamsCodec: const StandardMessageCodec(),
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS PlatformView needs explicit sizing to avoid zero frame
      // If width/height are null, the SizedBox will use constraints from parent
      // The iOS side will handle zero frames with a default size fallback
      return SizedBox(
        width: width,
        height: height,
        child: UiKitView(
          viewType: 'twilio_video_view',
          layoutDirection: TextDirection.ltr,
          creationParams: <String, dynamic>{
            'viewId': viewId,
          },
          creationParamsCodec: const StandardMessageCodec(),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

