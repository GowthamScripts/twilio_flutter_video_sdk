import 'package:flutter/material.dart';
import 'dart:async';
import 'twilio_video_controller.dart';
import 'twilio_video_room.dart';
import 'twilio_video_events.dart';
import 'twilio_video_view.dart';

/// Configuration options for VideoRoomScreen
class VideoRoomScreenOptions {
  /// Access token for joining the room
  final String accessToken;
  
  /// Room name to join
  final String roomName;
  
  /// Enable audio by default
  final bool enableAudio;
  
  /// Enable video by default
  final bool enableVideo;
  
  /// Use front camera by default
  final bool enableFrontCamera;
  
  /// Show input fields for token and room name (if false, uses provided values)
  final bool showInputFields;
  
  /// Custom app bar title
  final String? appBarTitle;
  
  /// Callback when room is connected
  final VoidCallback? onConnected;
  
  /// Callback when room is disconnected
  final VoidCallback? onDisconnected;
  
  /// Callback when connection fails
  final Function(String error)? onConnectionFailure;
  
  /// Custom local video widget builder
  final Widget Function(BuildContext context)? localVideoBuilder;
  
  /// Custom remote video widget builder
  final Widget Function(BuildContext context, String participantSid)? remoteVideoBuilder;
  
  /// Custom controls widget builder
  final Widget Function(BuildContext context, VideoRoomScreenController controller)? controlsBuilder;

  const VideoRoomScreenOptions({
    required this.accessToken,
    required this.roomName,
    this.enableAudio = true,
    this.enableVideo = true,
    this.enableFrontCamera = true,
    this.showInputFields = false,
    this.appBarTitle,
    this.onConnected,
    this.onDisconnected,
    this.onConnectionFailure,
    this.localVideoBuilder,
    this.remoteVideoBuilder,
    this.controlsBuilder,
  });
}

/// Controller for VideoRoomScreen to programmatically control the room
class VideoRoomScreenController {
  TwilioVideoRoom? _room;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;
  
  TwilioVideoRoom? get room => _room;
  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isFrontCamera => _isFrontCamera;
  
  void _updateRoom(TwilioVideoRoom? room) => _room = room;
  void _updateConnected(bool connected) => _isConnected = connected;
  void _updateMuted(bool muted) => _isMuted = muted;
  void _updateVideoEnabled(bool enabled) => _isVideoEnabled = enabled;
  void _updateFrontCamera(bool front) => _isFrontCamera = front;
  
  Future<void> toggleMute() async => await _room?.toggleMute();
  Future<void> toggleVideo() async => await _room?.toggleVideo();
  Future<void> switchCamera() async => await _room?.switchCamera();
  Future<void> disconnect() async => await _room?.disconnect();
}

/// A ready-to-use video room screen widget
class VideoRoomScreen extends StatefulWidget {
  final VideoRoomScreenOptions options;
  final VideoRoomScreenController? controller;

  const VideoRoomScreen({
    super.key,
    required this.options,
    this.controller,
  });

  @override
  State<VideoRoomScreen> createState() => _VideoRoomScreenState();
}

class _VideoRoomScreenState extends State<VideoRoomScreen> {
  final TwilioVideoController _videoController = TwilioVideoController();
  final TextEditingController _accessTokenController = TextEditingController();
  final TextEditingController _roomNameController = TextEditingController();
  
  late VideoRoomScreenController _controller;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;
  String _statusMessage = 'Not connected';
  String? _errorMessage;
  
  StreamSubscription<TwilioVideoEvent>? _eventSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<ParticipantInfo>? _participantSubscription;
  StreamSubscription<VideoTrackInfo>? _videoTrackSubscription;
  
  final Set<String> _remoteParticipantSids = {};

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? VideoRoomScreenController();
    _accessTokenController.text = widget.options.accessToken;
    _roomNameController.text = widget.options.roomName;
    _isVideoEnabled = widget.options.enableVideo;
    _isFrontCamera = widget.options.enableFrontCamera;
    _requestPermissions();
    // Auto-connect on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinRoom();
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _errorSubscription?.cancel();
    _participantSubscription?.cancel();
    _videoTrackSubscription?.cancel();
    _accessTokenController.dispose();
    _roomNameController.dispose();
    _controller._updateRoom(null);
    _controller._updateConnected(false);
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    // Note: Permissions should be requested by the app using permission_handler package
    // This is just a placeholder - users should request permissions before showing this screen
  }

  Future<void> _joinRoom() async {
    final accessToken = widget.options.showInputFields 
        ? _accessTokenController.text 
        : widget.options.accessToken;
    final roomName = widget.options.showInputFields 
        ? _roomNameController.text 
        : widget.options.roomName;

    if (accessToken.isEmpty || roomName.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter access token and room name';
      });
      return;
    }

    try {
      setState(() {
        _errorMessage = null;
        _statusMessage = 'Connecting...';
      });

      final room = _videoController.createRoom();
      _controller._updateRoom(room);

      // Listen to events
      _eventSubscription = room.events.listen((event) {
        _handleEvent(event);
      });

      _errorSubscription = room.errors.listen((error) {
        setState(() {
          _errorMessage = error;
          _statusMessage = 'Error: $error';
        });
        widget.options.onConnectionFailure?.call(error);
      });

      _participantSubscription = room.participantEvents.listen((participant) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Participant ${participant.identity} ${_isConnected ? "connected" : "disconnected"}'),
            duration: const Duration(seconds: 2),
          ),
        );
      });
      
      _videoTrackSubscription = room.videoTrackEvents.listen((track) {
        setState(() {
          if (track.isEnabled && track.nativeViewReady) {
            if (!_remoteParticipantSids.contains(track.participantSid)) {
              _remoteParticipantSids.add(track.participantSid);
            }
          } else {
            _remoteParticipantSids.remove(track.participantSid);
          }
        });
      });

      // Join room
      await room.joinRoom(
        RoomOptions(
          accessToken: accessToken,
          roomName: roomName,
          enableAudio: widget.options.enableAudio,
          enableVideo: widget.options.enableVideo,
          enableFrontCamera: widget.options.enableFrontCamera,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _statusMessage = 'Connection failed';
      });
      widget.options.onConnectionFailure?.call(e.toString());
    }
  }

  void _handleEvent(TwilioVideoEvent event) {
    switch (event) {
      case TwilioVideoEvent.connected:
        setState(() {
          _isConnected = true;
          _statusMessage = 'Connected';
        });
        _controller._updateConnected(true);
        widget.options.onConnected?.call();
        break;
      case TwilioVideoEvent.disconnected:
        setState(() {
          _isConnected = false;
          _statusMessage = 'Disconnected';
          _remoteParticipantSids.clear();
        });
        _controller._updateConnected(false);
        widget.options.onDisconnected?.call();
        break;
      case TwilioVideoEvent.connectionFailure:
        setState(() {
          _isConnected = false;
          _statusMessage = 'Connection failed';
        });
        _controller._updateConnected(false);
        break;
      default:
        break;
    }
  }

  Future<void> _disconnect() async {
    try {
      await _controller.disconnect();
      setState(() {
        _isConnected = false;
        _statusMessage = 'Disconnected';
        _remoteParticipantSids.clear();
      });
      _controller._updateConnected(false);
      widget.options.onDisconnected?.call();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _toggleMute() async {
    try {
      await _controller.toggleMute();
      setState(() {
        _isMuted = !_isMuted;
      });
      _controller._updateMuted(_isMuted);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _toggleVideo() async {
    try {
      await _controller.toggleVideo();
      setState(() {
        _isVideoEnabled = !_isVideoEnabled;
      });
      _controller._updateVideoEnabled(_isVideoEnabled);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  // Camera switch functionality available via controller if needed
  // Future<void> _switchCamera() async {
  //   try {
  //     await _controller.switchCamera();
  //     setState(() {
  //       _isFrontCamera = !_isFrontCamera;
  //     });
  //     _controller._updateFrontCamera(_isFrontCamera);
  //   } catch (e) {
  //     setState(() {
  //       _errorMessage = e.toString();
  //     });
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    // If not connected, show loading/connecting state
    if (!_isConnected) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Connected state - show video layout
    final remoteParticipantCount = _remoteParticipantSids.length;
    final isTwoMemberLayout = remoteParticipantCount == 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video content
          if (isTwoMemberLayout)
            _buildTwoMemberLayout()
          else
            _buildGridLayout(),
          
          // Bottom controls overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomControls(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoMemberLayout() {
    return Stack(
      children: [
        // Remote video - full screen
        if (_remoteParticipantSids.isNotEmpty)
          SizedBox.expand(
            child: TwilioVideoView(
              viewId: _remoteParticipantSids.first,
            ),
          )
        else
          const Center(
            child: Text(
              'Waiting for remote participant...',
              style: TextStyle(color: Colors.white),
            ),
          ),
        
        // Back button - top left
        Positioned(
          top: 40,
          left: 16,
          child: SafeArea(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
        
        // Local video - small top corner
        Positioned(
          top: 40,
          right: 16,
          child: SafeArea(
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: const TwilioVideoView(
                  viewId: "0",
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridLayout() {
    if (_remoteParticipantSids.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for remote participants...',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    // Calculate grid dimensions
    final participantCount = _remoteParticipantSids.length;
    int crossAxisCount = 2;
    if (participantCount <= 2) {
      crossAxisCount = 2;
    } else if (participantCount <= 4) {
      crossAxisCount = 2;
    } else if (participantCount <= 6) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 3;
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 4 / 3,
      ),
      itemCount: participantCount,
      itemBuilder: (context, index) {
        final participantSid = _remoteParticipantSids.elementAt(index);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              TwilioVideoView(viewId: participantSid),
              // Optional: Add participant label
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    participantSid.substring(0, 8),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Toggle Camera (Enable/Disable Local Video)
            _buildControlButton(
              icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
              onPressed: _toggleVideo,
              backgroundColor: _isVideoEnabled ? Colors.white : Colors.grey,
              iconColor: _isVideoEnabled ? Colors.black : Colors.white,
            ),
            
            // Mute/Unmute
            _buildControlButton(
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              onPressed: _toggleMute,
              backgroundColor: _isMuted ? Colors.grey : Colors.white,
              iconColor: _isMuted ? Colors.white : Colors.black,
            ),
            
            // End Call
            _buildControlButton(
              icon: Icons.call_end,
              onPressed: _disconnect,
              backgroundColor: Colors.red,
              iconColor: Colors.white,
              size: 56,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color iconColor,
    double size = 48,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: size * 0.5,
        ),
      ),
    );
  }

}

