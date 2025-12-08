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

  Future<void> _switchCamera() async {
    try {
      await _controller.switchCamera();
      setState(() {
        _isFrontCamera = !_isFrontCamera;
      });
      _controller._updateFrontCamera(_isFrontCamera);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.options.appBarTitle ?? 'Twilio Video Room'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status message
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: $_statusMessage',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Input fields (if enabled)
            if (widget.options.showInputFields) ...[
              TextField(
                controller: _accessTokenController,
                decoration: const InputDecoration(
                  labelText: 'Access Token',
                  hintText: 'Enter your Twilio access token',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isConnected,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _roomNameController,
                decoration: const InputDecoration(
                  labelText: 'Room Name',
                  hintText: 'Enter room name',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isConnected,
              ),
              const SizedBox(height: 24),
            ],
            
            // Join/Disconnect Button
            ElevatedButton(
              onPressed: _isConnected ? _disconnect : _joinRoom,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _isConnected
                    ? Colors.red
                    : Theme.of(context).primaryColor,
              ),
              child: Text(
                _isConnected ? 'End Meeting' : 'Join Room',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            
            // Video Views (only visible when connected)
            if (_isConnected) ...[
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Video',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              
              // Local video
              if (widget.options.localVideoBuilder != null)
                widget.options.localVideoBuilder!(context)
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Local Video',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 200,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: const TwilioVideoView(
                              viewId: "0",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              
              // Remote videos
              if (_remoteParticipantSids.isNotEmpty) ...[
                if (widget.options.remoteVideoBuilder != null)
                  ..._remoteParticipantSids.map((sid) => 
                    widget.options.remoteVideoBuilder!(context, sid)
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 4 / 3,
                    ),
                    itemCount: _remoteParticipantSids.length,
                    itemBuilder: (context, index) {
                      final participantSid = _remoteParticipantSids.elementAt(index);
                      return Card(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              TwilioVideoView(viewId: participantSid),
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
                        ),
                      );
                    },
                  ),
              ] else if (_isConnected) ...[
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'Waiting for remote participants...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
              
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Controls',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              
              // Controls
              if (widget.options.controlsBuilder != null)
                widget.options.controlsBuilder!(context, _controller)
              else
                _buildDefaultControls(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultControls(BuildContext context) {
    return Column(
      children: [
        // Mute/Unmute Button
        ElevatedButton.icon(
          onPressed: _toggleMute,
          icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
          label: Text(_isMuted ? 'Unmute' : 'Mute'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: _isMuted ? Colors.grey : Colors.green,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: 12),
        
        // Video On/Off Button
        ElevatedButton.icon(
          onPressed: _toggleVideo,
          icon: Icon(_isVideoEnabled ? Icons.videocam : Icons.videocam_off),
          label: Text(_isVideoEnabled ? 'Turn Video Off' : 'Turn Video On'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: _isVideoEnabled ? Colors.blue : Colors.grey,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
        const SizedBox(height: 12),
        
        // Switch Camera Button
        ElevatedButton.icon(
          onPressed: _switchCamera,
          icon: const Icon(Icons.cameraswitch),
          label: Text(_isFrontCamera ? 'Switch to Back Camera' : 'Switch to Front Camera'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.orange,
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }
}

