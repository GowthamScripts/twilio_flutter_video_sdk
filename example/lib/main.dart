import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:twilio_flutter_video_sdk/twilio_flutter_video_sdk.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Twilio Video SDK Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const VideoRoomScreen(),
    );
  }
}

class VideoRoomScreen extends StatefulWidget {
  const VideoRoomScreen({super.key});

  @override
  State<VideoRoomScreen> createState() => _VideoRoomScreenState();
}

class _VideoRoomScreenState extends State<VideoRoomScreen> {
  final TextEditingController _accessTokenController = TextEditingController();
  final TextEditingController _roomNameController = TextEditingController(text: 'APT-692D5652CECD7');
  final TwilioVideoController _videoController = TwilioVideoController();
  
  TwilioVideoRoom? _room;
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
  
  // Track remote participant SIDs for video views
  final Set<String> _remoteParticipantSids = {};

  @override
  void initState() {
    super.initState();
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
    _room?.disconnect();
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  Future<void> _joinRoom() async {
    if (_accessTokenController.text.isEmpty || _roomNameController.text.isEmpty) {
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

      _room = _videoController.createRoom();

      // Listen to events
      _eventSubscription = _room!.events.listen((event) {
        _handleEvent(event);
      });

      _errorSubscription = _room!.errors.listen((error) {
        setState(() {
          _errorMessage = error;
          _statusMessage = 'Error: $error';
        });
      });

      _participantSubscription = _room!.participantEvents.listen((participant) {
        print('📱 Participant event: ${participant.identity}, SID: ${participant.sid}, isConnected: $_isConnected');
        // Don't add to _remoteParticipantSids here - wait for videoTrackAdded event
        // This ensures the native VideoView exists before Flutter creates PlatformView
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Participant ${participant.identity} ${_isConnected ? "connected" : "disconnected"}'),
            duration: const Duration(seconds: 2),
          ),
        );
      });
      
      // Listen to video track events - ONLY add participantSid when video track is actually added
      // AND native VideoView is ready. This ensures the native VideoView exists before Flutter 
      // tries to create PlatformView, preventing "Waiting for video..." placeholders.
      _videoTrackSubscription = _room!.videoTrackEvents.listen((track) {
        print('🎥 Video track event: participantSid=${track.participantSid}, enabled=${track.isEnabled}, trackSid=${track.trackSid}, nativeViewReady=${track.nativeViewReady}');
        setState(() {
          if (track.isEnabled && track.nativeViewReady) {
            // Only add when track is enabled AND native view is ready
            // This ensures the native VideoView exists before Flutter creates PlatformView
            if (!_remoteParticipantSids.contains(track.participantSid)) {
              _remoteParticipantSids.add(track.participantSid);
              print('✅ Added remote participant with video (native view ready): ${track.participantSid}, total: ${_remoteParticipantSids.length}');
            }
          } else {
            // Remove when track is disabled, removed, or native view not ready
            if (_remoteParticipantSids.remove(track.participantSid)) {
              print('❌ Removed remote participant video: ${track.participantSid}, total: ${_remoteParticipantSids.length}');
            }
          }
        });
      });

      // Join room
      await _room!.joinRoom(
        RoomOptions(
          accessToken: _accessTokenController.text,
          roomName: _roomNameController.text,
          enableAudio: true,
          enableVideo: true,
          enableFrontCamera: _isFrontCamera,
        ),
      );

      setState(() {
        _isConnected = true;
        _statusMessage = 'Connected to ${_roomNameController.text}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _statusMessage = 'Connection failed';
        _isConnected = false;
      });
    }
  }

  void _handleEvent(TwilioVideoEvent event) {
    setState(() {
      switch (event) {
        case TwilioVideoEvent.connected:
          _statusMessage = 'Connected to ${_roomNameController.text}';
          _isConnected = true;
          break;
        case TwilioVideoEvent.disconnected:
          _statusMessage = 'Disconnected';
          _isConnected = false;
          _remoteParticipantSids.clear();
          break;
        case TwilioVideoEvent.connectionFailure:
          _statusMessage = 'Connection failed';
          _isConnected = false;
          break;
        case TwilioVideoEvent.reconnecting:
          _statusMessage = 'Reconnecting...';
          break;
        case TwilioVideoEvent.reconnected:
          _statusMessage = 'Reconnected';
          break;
        case TwilioVideoEvent.participantConnected:
          // Participant SID will be available from participant events
          break;
        case TwilioVideoEvent.participantDisconnected:
          // Participant SID will be removed from participant events
          break;
        case TwilioVideoEvent.videoTrackAdded:
          // Video track added - view will be available
          break;
        case TwilioVideoEvent.videoTrackRemoved:
          // Video track removed
          break;
        default:
          break;
      }
    });
  }

  Future<void> _disconnect() async {
    try {
      await _room?.disconnect();
      setState(() {
        _isConnected = false;
        _statusMessage = 'Disconnected';
        _isMuted = false;
        _isVideoEnabled = true;
        _remoteParticipantSids.clear();
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _toggleMute() async {
    try {
      await _room?.toggleMute();
      setState(() {
        _isMuted = !_isMuted;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _toggleVideo() async {
    try {
      await _room?.toggleVideo();
      setState(() {
        _isVideoEnabled = !_isVideoEnabled;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _room?.switchCamera();
      setState(() {
        _isFrontCamera = !_isFrontCamera;
      });
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
        title: const Text('Twilio Video Room'),
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
            
            // Access Token Input
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
            
            // Room Name Input
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
              
              // Local video view
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
                            width: double.infinity,
                            height: 200,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Remote video views
              // IMPORTANT: Only create PlatformViews AFTER receiving videoTrackAdded event
              // This ensures the native VideoView exists before Flutter tries to access it.
              // 
              // Flow:
              // 1. Participant connects -> participantConnected event (don't create view yet)
              // 2. Participant enables video -> didEnableVideoTrack (iOS) creates VideoView
              // 3. Native sends videoTrackAdded event -> Flutter adds participantSid to set
              // 4. Flutter rebuilds -> Creates TwilioVideoView widget -> PlatformView created
              // 5. PlatformView factory retrieves VideoView from native (now it exists!)
              // 
              // Debug: Check console logs for:
              // - "Video track event" - confirms track events are received
              // - "Added remote participant with video" - confirms participantSid is added
              // - "Creating TwilioVideoView widget" - confirms Flutter widget is created
              // - "Creating PlatformView" (iOS) - confirms native PlatformView is created
              // - "Found VideoView" (iOS) - confirms native VideoView is found
              // - "VideoView not found" (iOS) - means viewId mismatch or timing issue
              if (_remoteParticipantSids.isNotEmpty) ...[
                Text(
                  'Remote Participants (${_remoteParticipantSids.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 16 / 9,
                  ),
                  itemCount: _remoteParticipantSids.length,
                  itemBuilder: (context, index) {
                    final participantSid = _remoteParticipantSids.elementAt(index);
                    print('🎥 Creating TwilioVideoView widget for participant SID: $participantSid (index: $index)');
                    print('   Total remote participants: ${_remoteParticipantSids.length}');
                    print('   All participant SIDs: ${_remoteParticipantSids.toList()}');
                    return Card(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            TwilioVideoView(
                              viewId: participantSid,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                            // Debug overlay showing participant SID
                            Positioned(
                              bottom: 4,
                              left: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'SID: ${participantSid.substring(0, participantSid.length > 20 ? 20 : participantSid.length)}...',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ] else if (_isConnected) ...[
                // Show placeholder while waiting for remote participants
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
              
              // Mute/Unmute Button
              ElevatedButton.icon(
                onPressed: _toggleMute,
                icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                label: Text(_isMuted ? 'Unmute' : 'Mute'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _isMuted ? Colors.grey : Colors.green,
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
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            
            // Info Card
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('1. Enter your Twilio access token'),
                    Text('2. Enter a room name'),
                    Text('3. Click "Join Room" to connect'),
                    Text('4. Use the control buttons to manage your meeting'),
                    Text('5. Click "End Meeting" to disconnect'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
