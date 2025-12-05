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
  final TextEditingController _roomNameController = TextEditingController();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Participant ${participant.identity} ${_isConnected ? "connected" : "disconnected"}'),
            duration: const Duration(seconds: 2),
          ),
        );
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
            
            // Control Buttons (only visible when connected)
            if (_isConnected) ...[
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
