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
      home: const HomeScreen(),
    );
  }
}

/// Home screen with example options
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Twilio Video SDK Examples'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Choose an example to try:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // Example 1: Ready-to-use VideoRoomScreen
          Card(
            child: ListTile(
              leading: const Icon(Icons.video_call, size: 40),
              title: const Text('Example 1: Ready-to-Use VideoRoomScreen'),
              subtitle: const Text('Simplest way - just pass token and room name'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SimpleVideoRoomExample(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          
          // Example 2: Custom VideoRoomScreen
          Card(
            child: ListTile(
              leading: const Icon(Icons.tune, size: 40),
              title: const Text('Example 2: Custom VideoRoomScreen'),
              subtitle: const Text('Customize UI with builder functions'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CustomVideoRoomExample(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          
          // Example 3: Manual Implementation
          Card(
            child: ListTile(
              leading: const Icon(Icons.code, size: 40),
              title: const Text('Example 3: Manual Implementation'),
              subtitle: const Text('Full control - build your own UI'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManualVideoRoomExample(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Example 1: Simple usage with ready-to-use VideoRoomScreen
class SimpleVideoRoomExample extends StatefulWidget {
  const SimpleVideoRoomExample({super.key});

  @override
  State<SimpleVideoRoomExample> createState() => _SimpleVideoRoomExampleState();
}

class _SimpleVideoRoomExampleState extends State<SimpleVideoRoomExample> {
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  bool _hasPermissions = false;
  bool _isRequestingPermissions = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    // Prevent multiple simultaneous requests
    if (_isRequestingPermissions) {
      return;
    }
    
    try {
      _isRequestingPermissions = true;
      
      // Check current status first
      final cameraStatus = await Permission.camera.status;
      final microphoneStatus = await Permission.microphone.status;
      
      // If already granted, update state
      if (cameraStatus.isGranted && microphoneStatus.isGranted) {
        if (mounted) {
          setState(() {
            _hasPermissions = true;
          });
        }
        return;
      }
      
      // Request permissions one by one for better iOS compatibility
      final cameraResult = await Permission.camera.request();
      
      final micResult = await Permission.microphone.request();
      
      // Check final status
      final finalCameraStatus = await Permission.camera.status;
      final finalMicStatus = await Permission.microphone.status;
      
      if (mounted) {
        final granted = finalCameraStatus.isGranted && finalMicStatus.isGranted;
        setState(() {
          _hasPermissions = granted;
        });
        
        // Use request result to check for permanently denied (more reliable on iOS)
        final cameraPermanentlyDenied = cameraResult.isPermanentlyDenied || finalCameraStatus.isPermanentlyDenied;
        final micPermanentlyDenied = micResult.isPermanentlyDenied || finalMicStatus.isPermanentlyDenied;
        
        // If denied permanently, show message
        if (!granted) {
          if (cameraPermanentlyDenied || micPermanentlyDenied) {
            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Permissions Required'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Camera and microphone permissions are required for video calls.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        const Text('To enable permissions:'),
                        const SizedBox(height: 8),
                        const Text('1. Tap "Open Settings" below'),
                        const Text('2. Go to Privacy & Security'),
                        const Text('3. Tap Camera or Microphone'),
                        const Text('4. Find "Twilio Flutter Video Sdk" and enable it'),
                        const SizedBox(height: 16),
                        const Text(
                          'If you don\'t see this app in Settings:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• Delete and reinstall the app\n'
                          '• Then grant permissions when prompted',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        openAppSettings();
                      },
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
              );
            }
          } else {
            // Show message if denied but not permanently
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permissions were denied. Please grant camera and microphone access.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting permissions: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _isRequestingPermissions = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermissions) {
      return Scaffold(
        appBar: AppBar(title: const Text('Example 1: Simple VideoRoomScreen')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Camera and Microphone Permissions Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  'This app needs access to your camera and microphone for video calls.',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _requestPermissions,
                icon: const Icon(Icons.lock_open),
                label: const Text('Grant Permissions'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Example 1: Simple VideoRoomScreen'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.green.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This example shows the simplest way to use the plugin:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('• Just pass access token and room name'),
                    Text('• All UI and controls are built-in'),
                    Text('• Perfect for quick prototyping'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Access Token',
                hintText: 'Enter your Twilio access token',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roomController,
              decoration: const InputDecoration(
                labelText: 'Room Name',
                hintText: 'Enter room name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (_tokenController.text.isEmpty || _roomController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter token and room name')),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoRoomScreen(
                      options: VideoRoomScreenOptions(
                        accessToken: _tokenController.text,
                        roomName: _roomController.text,
                        enableAudio: true,
                        enableVideo: true,
                        enableFrontCamera: true,
                        onConnected: () {
                          // Connected to room
                        },
                        onDisconnected: () {
                          Navigator.pop(context);
                        },
                        onConnectionFailure: (error) {
                          // Connection failed
                        },
                      ),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Join Room'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Example 2: Custom VideoRoomScreen with custom builders
class CustomVideoRoomExample extends StatefulWidget {
  const CustomVideoRoomExample({super.key});

  @override
  State<CustomVideoRoomExample> createState() => _CustomVideoRoomExampleState();
}

class _CustomVideoRoomExampleState extends State<CustomVideoRoomExample> {
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _roomController = TextEditingController(text: 'test');
  bool _hasPermissions = false;
  bool _isRequestingPermissions = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    // Prevent multiple simultaneous requests
    if (_isRequestingPermissions) {
      return;
    }
    
    try {
      _isRequestingPermissions = true;
      
      // Check current status first
      final cameraStatus = await Permission.camera.status;
      final microphoneStatus = await Permission.microphone.status;
      
      // If already granted, update state
      if (cameraStatus.isGranted && microphoneStatus.isGranted) {
        if (mounted) {
          setState(() {
            _hasPermissions = true;
          });
        }
        return;
      }
      
      // Request permissions one by one for better iOS compatibility
      final cameraResult = await Permission.camera.request();
      
      final micResult = await Permission.microphone.request();
      
      // Check final status
      final finalCameraStatus = await Permission.camera.status;
      final finalMicStatus = await Permission.microphone.status;
      
      if (mounted) {
        final granted = finalCameraStatus.isGranted && finalMicStatus.isGranted;
        setState(() {
          _hasPermissions = granted;
        });
        
        // Use request result to check for permanently denied (more reliable on iOS)
        final cameraPermanentlyDenied = cameraResult.isPermanentlyDenied || finalCameraStatus.isPermanentlyDenied;
        final micPermanentlyDenied = micResult.isPermanentlyDenied || finalMicStatus.isPermanentlyDenied;
        
        // If denied permanently, show message
        if (!granted) {
          if (cameraPermanentlyDenied || micPermanentlyDenied) {
            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Permissions Required'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Camera and microphone permissions are required for video calls.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        const Text('To enable permissions:'),
                        const SizedBox(height: 8),
                        const Text('1. Tap "Open Settings" below'),
                        const Text('2. Go to Privacy & Security'),
                        const Text('3. Tap Camera or Microphone'),
                        const Text('4. Find "Twilio Flutter Video Sdk" and enable it'),
                        const SizedBox(height: 16),
                        const Text(
                          'If you don\'t see this app in Settings:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• Delete and reinstall the app\n'
                          '• Then grant permissions when prompted',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        openAppSettings();
                      },
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
              );
            }
          } else {
            // Show message if denied but not permanently
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permissions were denied. Please grant camera and microphone access.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting permissions: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _isRequestingPermissions = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermissions) {
      return Scaffold(
        appBar: AppBar(title: const Text('Example 2: Custom VideoRoomScreen')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Camera and Microphone Permissions Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _requestPermissions,
                icon: const Icon(Icons.lock_open),
                label: const Text('Grant Permissions'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Example 2: Custom VideoRoomScreen'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This example shows how to customize the UI:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('• Custom local video widget'),
                    Text('• Custom remote video widget'),
                    Text('• Custom controls layout'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Access Token',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roomController,
              decoration: const InputDecoration(
                labelText: 'Room Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (_tokenController.text.isEmpty || _roomController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter token and room name')),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoRoomScreen(
                      options: VideoRoomScreenOptions(
                        accessToken: _tokenController.text,
                        roomName: _roomController.text,
                        // Custom local video
                        localVideoBuilder: (context) => Container(
                          height: 150,
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue, width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: const TwilioVideoView(viewId: "0"),
                          ),
                        ),
                        // Custom remote video
                        remoteVideoBuilder: (context, participantSid) => Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green, width: 1),
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: TwilioVideoView(viewId: participantSid),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    participantSid.substring(0, 8),
                                    style: const TextStyle(color: Colors.white, fontSize: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Custom controls
                        controlsBuilder: (context, controller) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            FloatingActionButton(
                              heroTag: 'mute',
                              onPressed: controller.toggleMute,
                              backgroundColor: controller.isMuted ? Colors.red : Colors.green,
                              child: Icon(controller.isMuted ? Icons.mic_off : Icons.mic),
                            ),
                            FloatingActionButton(
                              heroTag: 'video',
                              onPressed: controller.toggleVideo,
                              backgroundColor: controller.isVideoEnabled ? Colors.blue : Colors.grey,
                              child: Icon(controller.isVideoEnabled ? Icons.videocam : Icons.videocam_off),
                            ),
                            FloatingActionButton(
                              heroTag: 'camera',
                              onPressed: controller.switchCamera,
                              backgroundColor: Colors.orange,
                              child: const Icon(Icons.cameraswitch),
                            ),
                            FloatingActionButton(
                              heroTag: 'disconnect',
                              onPressed: () {
                                controller.disconnect();
                                Navigator.pop(context);
                              },
                              backgroundColor: Colors.red,
                              child: const Icon(Icons.call_end),
                            ),
                          ],
                        ),
                        onConnected: () {
                          // Connected
                        },
                        onDisconnected: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Join Room with Custom UI'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Example 3: Manual implementation (full control)
class ManualVideoRoomExample extends StatefulWidget {
  const ManualVideoRoomExample({super.key});

  @override
  State<ManualVideoRoomExample> createState() => _ManualVideoRoomExampleState();
}

class _ManualVideoRoomExampleState extends State<ManualVideoRoomExample> {
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
  bool _isRequestingPermissions = false;
  
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
    // Prevent multiple simultaneous requests
    if (_isRequestingPermissions) {
      return;
    }
    
    try {
      _isRequestingPermissions = true;
      
      // Check current status first
      final cameraStatus = await Permission.camera.status;
      final microphoneStatus = await Permission.microphone.status;
      
      // If already granted, return early
      if (cameraStatus.isGranted && microphoneStatus.isGranted) {
        return;
      }
      
      // Request permissions one by one for better iOS compatibility
      final cameraResult = await Permission.camera.request();
      
      final micResult = await Permission.microphone.request();
      
      // Check final status
      final finalCameraStatus = await Permission.camera.status;
      final finalMicStatus = await Permission.microphone.status;
      
      // Use request result to check for permanently denied (more reliable on iOS)
      final cameraPermanentlyDenied = cameraResult.isPermanentlyDenied || finalCameraStatus.isPermanentlyDenied;
      final micPermanentlyDenied = micResult.isPermanentlyDenied || finalMicStatus.isPermanentlyDenied;
      
      if ((cameraPermanentlyDenied || micPermanentlyDenied) && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permissions Required'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Camera and microphone permissions are required for video calls.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('To enable permissions:'),
                  const SizedBox(height: 8),
                  const Text('1. Tap "Open Settings" below'),
                  const Text('2. Go to Privacy & Security'),
                  const Text('3. Tap Camera or Microphone'),
                  const Text('4. Find "Twilio Flutter Video Sdk" and enable it'),
                  const SizedBox(height: 16),
                  const Text(
                    'If you don\'t see this app in Settings:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Delete and reinstall the app\n'
                    '• Then grant permissions when prompted',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      } else if (!finalCameraStatus.isGranted || !finalMicStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permissions were denied. Please grant camera and microphone access.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting permissions: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _isRequestingPermissions = false;
    }
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
        if (!mounted) return;
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
        setState(() {
          if (track.isEnabled && track.nativeViewReady) {
            // Only add when track is enabled AND native view is ready
            // This ensures the native VideoView exists before Flutter creates PlatformView
            if (!_remoteParticipantSids.contains(track.participantSid)) {
              _remoteParticipantSids.add(track.participantSid);
            }
          } else {
            // Remove when track is disabled, removed, or native view not ready
            _remoteParticipantSids.remove(track.participantSid);
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
        title: const Text('Example 3: Manual Implementation'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.purple.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This example shows full manual control:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('• Complete control over UI and logic'),
                    Text('• Handle all events manually'),
                    Text('• Customize everything to your needs'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
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
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Remote video views
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
                    return Card(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            TwilioVideoView(
                              viewId: participantSid,
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
