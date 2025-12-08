/// Events emitted by the Twilio Video SDK
enum TwilioVideoEvent {
  /// Participant connected to the room
  participantConnected,

  /// Participant disconnected from the room
  participantDisconnected,

  /// Video track was added
  videoTrackAdded,

  /// Video track was removed
  videoTrackRemoved,

  /// Audio track was added
  audioTrackAdded,

  /// Audio track was removed
  audioTrackRemoved,

  /// Room connection failed
  connectionFailure,

  /// Room was connected successfully
  connected,

  /// Room was disconnected
  disconnected,

  /// Reconnecting to the room
  reconnecting,

  /// Reconnected to the room
  reconnected,

  /// Dominant speaker changed
  dominantSpeakerChanged,
}

/// Participant information
class ParticipantInfo {
  final String sid;
  final String identity;
  final bool isAudioEnabled;
  final bool isVideoEnabled;

  ParticipantInfo({
    required this.sid,
    required this.identity,
    required this.isAudioEnabled,
    required this.isVideoEnabled,
  });

  factory ParticipantInfo.fromMap(Map<dynamic, dynamic> map) {
    return ParticipantInfo(
      sid: map['sid'] as String,
      identity: map['identity'] as String,
      isAudioEnabled: map['isAudioEnabled'] as bool? ?? false,
      isVideoEnabled: map['isVideoEnabled'] as bool? ?? false,
    );
  }
}

/// Video track information
class VideoTrackInfo {
  final String trackSid;
  final String participantSid;
  final bool isEnabled;
  final bool nativeViewReady;

  VideoTrackInfo({
    required this.trackSid,
    required this.participantSid,
    required this.isEnabled,
    this.nativeViewReady = false,
  });

  factory VideoTrackInfo.fromMap(Map<dynamic, dynamic> map) {
    return VideoTrackInfo(
      trackSid: map['trackSid'] as String,
      participantSid: map['participantSid'] as String,
      isEnabled: map['isEnabled'] as bool? ?? false,
      nativeViewReady: map['nativeViewReady'] as bool? ?? false,
    );
  }
}

