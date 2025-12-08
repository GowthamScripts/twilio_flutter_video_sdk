import Flutter
import UIKit
import TwilioVideo
import AVFoundation

public class TwilioFlutterVideoSdkPlugin: NSObject, FlutterPlugin {
    
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    private var registrar: FlutterPluginRegistrar?
    
    private var room: Room?
    private var camera: CameraSource?
    private var localVideoTrack: LocalVideoTrack?
    private var localAudioTrack: LocalAudioTrack?
    fileprivate var localVideoView: VideoView?
    
    fileprivate var remoteVideoViews: [String: VideoView] = [:]
    private var remoteVideoTracks: [String: RemoteVideoTrack] = [:]
    
    private var isAudioEnabled = true
    private var isVideoEnabled = true
    private var isFrontCamera = true
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: "twilio_flutter_video_sdk", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "twilio_flutter_video_sdk_events", binaryMessenger: registrar.messenger())
        
        let instance = TwilioFlutterVideoSdkPlugin()
        instance.methodChannel = methodChannel
        instance.eventChannel = eventChannel
        instance.registrar = registrar
        
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
        
        // Register PlatformView factory for dynamic view creation
        let factory = TwilioVideoViewFactory(plugin: instance)
        registrar.register(factory, withId: "twilio_video_view")
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
            
        case "joinRoom":
            joinRoom(call: call, result: result)
            
        case "disconnect":
            disconnect(result: result)
            
        case "setMuted":
            if let args = call.arguments as? [String: Any],
               let muted = args["muted"] as? Bool {
                setMuted(muted: muted, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Muted parameter is required", details: nil))
            }
            
        case "setVideoEnabled":
            if let args = call.arguments as? [String: Any],
               let enabled = args["enabled"] as? Bool {
                setVideoEnabled(enabled: enabled, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Enabled parameter is required", details: nil))
            }
            
        case "switchCamera":
            switchCamera(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func joinRoom(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let accessToken = args["accessToken"] as? String,
              let roomName = args["roomName"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Access token and room name are required", details: nil))
            return
        }
        
        let enableAudio = args["enableAudio"] as? Bool ?? true
        let enableVideo = args["enableVideo"] as? Bool ?? true
        let enableFrontCamera = args["enableFrontCamera"] as? Bool ?? true
        
        isAudioEnabled = enableAudio
        isVideoEnabled = enableVideo
        isFrontCamera = enableFrontCamera
        
        do {
            // Create camera source with options
            let options = CameraSourceOptions { builder in
                // Configure options if needed
            }
            camera = CameraSource(options: options, delegate: self)
            
            // Create local video track
            if enableVideo, let camera = camera {
                localVideoTrack = LocalVideoTrack(source: camera, enabled: true, name: "local-video-track")
                
                // Setup local video view
                setupLocalVideoView()
                
                // Start capturing with the requested camera position
                let position: AVCaptureDevice.Position = enableFrontCamera ? .front : .back
                if let device = captureDevice(for: position) {
                    camera.startCapture(device: device) { device, format, error in
                        if let error = error {
                            print("Camera startCapture error: \(error.localizedDescription)")
                        } else {
                            print("Camera started with device: \(String(describing: device))")
                        }
                    }
                } else if let defaultDevice = AVCaptureDevice.default(for: .video) {
                    // Fallback to default device
                    camera.startCapture(device: defaultDevice) { _, _, error in
                        if let error = error {
                            print("Camera startCapture fallback error: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            // Create local audio track
            if enableAudio {
                localAudioTrack = LocalAudioTrack(options: AudioOptions(), enabled: true, name: "local-audio-track")
            }
            
            // Prepare connect options
            let connectOptions = ConnectOptions(token: accessToken) { builder in
                builder.roomName = roomName
                
                if let videoTrack = self.localVideoTrack {
                    builder.videoTracks = [videoTrack]
                }
                
                if let audioTrack = self.localAudioTrack {
                    builder.audioTracks = [audioTrack]
                }
            }
            
            // Connect to room
            room = TwilioVideoSDK.connect(options: connectOptions, delegate: self)
            
            result(nil)
        } catch {
            result(FlutterError(code: "JOIN_ROOM_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func disconnect(result: @escaping FlutterResult) {
        room?.disconnect()
        camera?.stopCapture()
        
        // Clean up video views
        localVideoView = nil
        remoteVideoViews.removeAll()
        remoteVideoTracks.removeAll()
        
        localVideoTrack = nil
        localAudioTrack = nil
        camera = nil
        room = nil
        
        sendEvent(event: "disconnected", data: [:])
        result(nil)
    }
    
    private func setupLocalVideoView() {
        guard let videoTrack = localVideoTrack else { return }
        
        let videoView = VideoView(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        videoView.contentMode = .scaleAspectFill
        videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        videoTrack.addRenderer(videoView)
        localVideoView = videoView
        
        print("✅ TwilioVideoPlugin: Local video view created and attached")
    }
    
    func getVideoView(for viewId: String) -> VideoView? {
        if viewId == "0" {
            return localVideoView
        } else {
            let view = remoteVideoViews[viewId]
            if view == nil {
                print("⚠️ TwilioVideoPlugin: VideoView not found for viewId: \(viewId)")
                print("   Available remote views: \(Array(remoteVideoViews.keys))")
            } else {
                print("✅ TwilioVideoPlugin: Found VideoView for viewId: \(viewId)")
            }
            return view
        }
    }
    
    private func setMuted(muted: Bool, result: @escaping FlutterResult) {
        isAudioEnabled = !muted
        localAudioTrack?.isEnabled = !muted
        result(nil)
    }
    
    private func setVideoEnabled(enabled: Bool, result: @escaping FlutterResult) {
        isVideoEnabled = enabled
        localVideoTrack?.isEnabled = enabled
        result(nil)
    }
    
    private func switchCamera(result: @escaping FlutterResult) {
        guard let camera = camera else {
            result(FlutterError(code: "SWITCH_CAMERA_ERROR", message: "Camera not initialized", details: nil))
            return
        }
        
        isFrontCamera = !isFrontCamera
        
        // Determine new camera position
        let newPosition: AVCaptureDevice.Position = isFrontCamera ? .front : .back
        
        // Get the new capture device
        guard let newDevice = captureDevice(for: newPosition) else {
            result(FlutterError(code: "SWITCH_CAMERA_ERROR", message: "No capture device available for position", details: nil))
            return
        }
        
        // Stop current capture and start with new device
        camera.stopCapture()
        camera.startCapture(device: newDevice) { device, format, error in
            if let error = error {
                result(FlutterError(code: "SWITCH_CAMERA_ERROR", message: error.localizedDescription, details: nil))
            } else {
                result(nil)
            }
        }
    }
    
    // Helper: get capture device by position
    private func captureDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        return CameraSource.captureDevice(position: position)
    }
    
    private func sendEvent(event: String, data: [String: Any]) {
        var eventData = data
        eventData["event"] = event
        eventSink?(eventData)
    }
}

// MARK: - FlutterStreamHandler
extension TwilioFlutterVideoSdkPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

// MARK: - RemoteParticipantDelegate
extension TwilioFlutterVideoSdkPlugin: RemoteParticipantDelegate {
    public func didSubscribeToVideoTrack(videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication, participant: RemoteParticipant) {
        let participantSid = participant.sid ?? ""
        let trackSid = publication.trackSid ?? ""
        
        print("📹 TwilioVideoPlugin: didSubscribeToVideoTrack for participant: \(participantSid), trackSid: \(trackSid)")
        
        // Handle the subscribed video track
        handleRemoteVideoTrack(participant: participant, videoTrack: publication, remoteTrack: videoTrack)
    }
    
    public func didUnsubscribeFromVideoTrack(videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication, participant: RemoteParticipant) {
        let participantSid = participant.sid ?? ""
        let trackSid = publication.trackSid ?? ""
        
        print("📹 TwilioVideoPlugin: didUnsubscribeFromVideoTrack for participant: \(participantSid)")
        
        // Remove remote video view
        if let remoteView = remoteVideoViews.removeValue(forKey: participantSid) {
            remoteView.removeFromSuperview()
        }
        remoteVideoTracks.removeValue(forKey: participantSid)
        
        sendEvent(event: "videoTrackRemoved", data: [
            "track": [
                "trackSid": trackSid,
                "participantSid": participantSid,
                "isEnabled": false
            ]
        ])
    }
    
    public func didSubscribeToAudioTrack(audioTrack: RemoteAudioTrack, publication: RemoteAudioTrackPublication, participant: RemoteParticipant) {
        let participantSid = participant.sid ?? ""
        sendEvent(event: "audioTrackAdded", data: [
            "participantSid": participantSid
        ])
    }
    
    public func didUnsubscribeFromAudioTrack(audioTrack: RemoteAudioTrack, publication: RemoteAudioTrackPublication, participant: RemoteParticipant) {
        let participantSid = participant.sid ?? ""
        sendEvent(event: "audioTrackRemoved", data: [
            "participantSid": participantSid
        ])
    }
}

// MARK: - RoomDelegate
extension TwilioFlutterVideoSdkPlugin: RoomDelegate {
    public func roomDidConnect(room: Room) {
        // Store room reference
        self.room = room
        
        print("🏠 TwilioVideoPlugin: Room connected: \(room.name ?? "unknown")")
        print("   Total remote participants: \(room.remoteParticipants.count)")
        
        // When we join a room, check for existing participants who may already have video tracks
        // This handles the case where remote participants joined before us
        for participant in room.remoteParticipants {
            let participantSid = participant.sid ?? ""
            print("📱 TwilioVideoPlugin: Found existing participant: \(participant.identity ?? ""), SID: \(participantSid)")
            
            // Set delegate on existing participant to receive track events
            participant.delegate = self
            
            // Check for already-subscribed video tracks
            print("📹 TwilioVideoPlugin: Checking existing participant's video tracks...")
            print("   Total remoteVideoTracks: \(participant.remoteVideoTracks.count)")
            
            for videoTrackPublication in participant.remoteVideoTracks {
                let trackName = videoTrackPublication.trackName
                print("   Track: \(trackName), isSubscribed: \(videoTrackPublication.isTrackSubscribed)")
                if let remoteTrack = videoTrackPublication.remoteTrack, videoTrackPublication.isTrackSubscribed {
                    print("📹 TwilioVideoPlugin: Found existing subscribed video track for participant: \(participantSid)")
                    // Handle the existing track
                    handleRemoteVideoTrack(participant: participant, videoTrack: videoTrackPublication, remoteTrack: remoteTrack)
                } else if videoTrackPublication.isTrackSubscribed {
                    print("📹 TwilioVideoPlugin: Track is subscribed but remoteTrack is nil for participant: \(participantSid)")
                } else {
                    print("📹 TwilioVideoPlugin: Video track exists but not subscribed yet for participant: \(participantSid)")
                }
            }
        }
        
        sendEvent(event: "connected", data: ["roomName": room.name ?? ""])
    }
    
    public func roomDidFailToConnect(room: Room, error: Error) {
        sendEvent(event: "connectionFailure", data: ["error": error.localizedDescription])
    }
    
    public func roomDidDisconnect(room: Room, error: Error?) {
        sendEvent(event: "disconnected", data: [:])
    }
    
    public func roomIsReconnecting(room: Room, error: Error) {
        sendEvent(event: "reconnecting", data: [:])
    }
    
    public func roomDidReconnect(room: Room) {
        sendEvent(event: "reconnected", data: [:])
    }
    
    public func participantDidConnect(room: Room, participant: RemoteParticipant) {
        let participantSid = participant.sid ?? ""
        let participantIdentity = participant.identity ?? ""
        
        print("📱 TwilioVideoPlugin: Participant connected: \(participantIdentity), SID: \(participantSid)")
        
        // Set delegate on participant to receive track subscription events
        participant.delegate = self
        
        // Check for existing video tracks that are already published when participant connects
        // In Twilio Video SDK, tracks might already be available when participantDidConnect is called
        print("📹 TwilioVideoPlugin: Checking for existing video tracks...")
        print("   Total remoteVideoTracks: \(participant.remoteVideoTracks.count)")
        
        // Iterate over remoteVideoTracks (it's a collection, not a dictionary in SDK 5.x)
        for videoTrackPublication in participant.remoteVideoTracks {
            let trackName = videoTrackPublication.trackName
            print("   Track: \(trackName), isSubscribed: \(videoTrackPublication.isTrackSubscribed)")
            if let remoteTrack = videoTrackPublication.remoteTrack, videoTrackPublication.isTrackSubscribed {
                print("📹 TwilioVideoPlugin: Found existing subscribed video track for participant: \(participantSid)")
                // Handle the existing track as if it was just enabled
                handleRemoteVideoTrack(participant: participant, videoTrack: videoTrackPublication, remoteTrack: remoteTrack)
            } else if videoTrackPublication.isTrackSubscribed {
                print("📹 TwilioVideoPlugin: Track is subscribed but remoteTrack is nil for participant: \(participantSid)")
            } else {
                print("📹 TwilioVideoPlugin: Video track exists but not subscribed yet for participant: \(participantSid)")
            }
        }
        
        sendEvent(event: "participantConnected", data: [
            "participant": [
                "sid": participantSid,
                "identity": participantIdentity,
                "isAudioEnabled": true,
                "isVideoEnabled": true
            ]
        ])
    }
    
    // Helper method to handle remote video track (used for both existing and newly enabled tracks)
    private func handleRemoteVideoTrack(participant: RemoteParticipant, videoTrack: RemoteVideoTrackPublication, remoteTrack: RemoteVideoTrack) {
        let participantSid = participant.sid ?? ""
        let trackSid = videoTrack.trackSid ?? ""
        
        // Check if we already have a view for this participant to avoid duplicates
        if remoteVideoViews[participantSid] != nil {
            print("📹 TwilioVideoPlugin: Video view already exists for participant: \(participantSid), skipping creation")
            return
        }
        
        print("📹 TwilioVideoPlugin: Creating video view for participant: \(participantSid), trackSid: \(trackSid)")
        
        // Create video view for remote participant with proper configuration
        let remoteView = VideoView(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
        remoteView.contentMode = .scaleAspectFill
        remoteView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Attach the remote track to the video view
        remoteTrack.addRenderer(remoteView)
        
        // Store references to prevent deallocation
        remoteVideoViews[participantSid] = remoteView
        remoteVideoTracks[participantSid] = remoteTrack
        
        print("✅ TwilioVideoPlugin: Video view created and attached for participant: \(participantSid)")
        print("   Total remote views: \(remoteVideoViews.count)")
        print("   VideoView frame: \(remoteView.frame)")
        
        // Remote video view is now available via factory
        // Send event with nativeViewReady flag to ensure Flutter waits for native view
        sendEvent(event: "videoTrackAdded", data: [
            "track": [
                "trackSid": trackSid,
                "participantSid": participantSid,
                "isEnabled": true,
                "nativeViewReady": true  // Flag indicating native VideoView is ready
            ]
        ])
    }
    
    public func participantDidDisconnect(room: Room, participant: RemoteParticipant) {
        let participantSid = participant.sid ?? ""
        let participantIdentity = participant.identity ?? ""
        
        // Clean up remote video view
        let hadVideoView = remoteVideoViews[participantSid] != nil
        if let remoteView = remoteVideoViews.removeValue(forKey: participantSid) {
            remoteView.removeFromSuperview()
        }
        remoteVideoTracks.removeValue(forKey: participantSid)
        
        // If there was a video view, notify Flutter to remove the PlatformView
        if hadVideoView {
            sendEvent(event: "videoTrackRemoved", data: [
                "track": [
                    "trackSid": "",
                    "participantSid": participantSid,
                    "isEnabled": false
                ]
            ])
        }
        
        sendEvent(event: "participantDisconnected", data: [
            "participant": [
                "sid": participantSid,
                "identity": participantIdentity,
                "isAudioEnabled": false,
                "isVideoEnabled": false
            ]
        ])
    }
    
    public func participant(participant: RemoteParticipant, didEnableVideoTrack videoTrack: RemoteVideoTrackPublication) {
        guard let remoteTrack = videoTrack.remoteTrack else { 
            print("⚠️ TwilioVideoPlugin: didEnableVideoTrack but remoteTrack is nil")
            return 
        }
        
        let participantSid = participant.sid ?? ""
        print("📹 TwilioVideoPlugin: didEnableVideoTrack called for participant: \(participantSid)")
        
        // If we already have a view, just reattach the track
        if let existingView = remoteVideoViews[participantSid] {
            print("📹 TwilioVideoPlugin: Reattaching track to existing view for participant: \(participantSid)")
            // Remove any old renderer first (in case it was attached to a different track)
            if let oldTrack = remoteVideoTracks[participantSid] {
                oldTrack.removeRenderer(existingView)
            }
            // Clear background color that was set when disabled
            existingView.backgroundColor = .clear
            // Attach new track
            remoteTrack.addRenderer(existingView)
            remoteVideoTracks[participantSid] = remoteTrack
            
            // Send event with isEnabled: true
            sendEvent(event: "videoTrackAdded", data: [
                "track": [
                    "trackSid": videoTrack.trackSid ?? "",
                    "participantSid": participantSid,
                    "isEnabled": true,
                    "nativeViewReady": true
                ]
            ])
        } else {
            // Create new view if we don't have one
            handleRemoteVideoTrack(participant: participant, videoTrack: videoTrack, remoteTrack: remoteTrack)
        }
    }
    
    public func participant(participant: RemoteParticipant, didDisableVideoTrack videoTrack: RemoteVideoTrackPublication) {
        let participantSid = participant.sid ?? ""
        let trackSid = videoTrack.trackSid ?? ""
        
        print("📹 TwilioVideoPlugin: didDisableVideoTrack for participant: \(participantSid)")
        
        // Remove the renderer from the track to stop rendering and prevent frozen frame
        if let existingView = remoteVideoViews[participantSid],
           let existingTrack = remoteVideoTracks[participantSid] {
            print("📹 TwilioVideoPlugin: Removing renderer from track to stop video rendering")
            existingTrack.removeRenderer(existingView)
            // Clear the view background to show placeholder
            existingView.backgroundColor = .black
        }
        
        // Send event to Flutter so it can hide the video and show placeholder
        // Don't remove the view - keep it for reattaching when video is enabled again
        sendEvent(event: "videoTrackAdded", data: [
            "track": [
                "trackSid": trackSid,
                "participantSid": participantSid,
                "isEnabled": false,
                "nativeViewReady": remoteVideoViews[participantSid] != nil
            ]
        ])
    }
    
    public func participant(participant: RemoteParticipant, didEnableAudioTrack audioTrack: RemoteAudioTrackPublication) {
        let participantSid = participant.sid ?? ""
        sendEvent(event: "audioTrackAdded", data: [
            "participantSid": participantSid
        ])
    }
    
    public func participant(participant: RemoteParticipant, didDisableAudioTrack audioTrack: RemoteAudioTrackPublication) {
        let participantSid = participant.sid ?? ""
        sendEvent(event: "audioTrackRemoved", data: [
            "participantSid": participantSid
        ])
    }
    
    public func dominantSpeakerDidChange(room: Room, participant: RemoteParticipant?) {
        if let participant = participant {
            let participantSid = participant.sid ?? ""
            sendEvent(event: "dominantSpeakerChanged", data: [
                "participantSid": participantSid
            ])
        }
    }
}

// MARK: - CameraSourceDelegate
extension TwilioFlutterVideoSdkPlugin: CameraSourceDelegate {
    public func cameraSourceDidStart(source: CameraSource) {
        // Camera started successfully
    }
    
    public func cameraSourceWasInterrupted(source: CameraSource, reason: AVCaptureSession.InterruptionReason) {
        // Camera was interrupted
    }
    
    public func cameraSourceInterruptionEnded(source: CameraSource) {
        // Camera interruption ended
    }
    
    public func cameraSourceDidFail(source: CameraSource, error: Error) {
        sendEvent(event: "error", data: ["error": error.localizedDescription])
    }
}

// MARK: - PlatformView Factory
class TwilioVideoViewFactory: NSObject, FlutterPlatformViewFactory {
    private weak var plugin: TwilioFlutterVideoSdkPlugin?
    
    init(plugin: TwilioFlutterVideoSdkPlugin) {
        self.plugin = plugin
        super.init()
    }
    
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        // Extract viewId from creationParams
        var viewIdString = "0" // default to local
        if let argsDict = args as? [String: Any], let id = argsDict["viewId"] as? String {
            viewIdString = id
        }
        
        print("🏭 TwilioVideoViewFactory: Creating PlatformView with viewId: '\(viewIdString)'")
        if let plugin = plugin {
            print("   Available local view: \(plugin.localVideoView != nil ? "YES" : "NO")")
            print("   Available remote views: \(Array(plugin.remoteVideoViews.keys))")
        }
        
        return TwilioVideoPlatformView(frame: frame, viewId: viewIdString, plugin: plugin)
    }
    
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

// MARK: - PlatformView
class TwilioVideoPlatformView: NSObject, FlutterPlatformView {
    private var frame: CGRect
    private var viewId: String
    private weak var plugin: TwilioFlutterVideoSdkPlugin?
    private var containerView: UIView?
    
    init(frame: CGRect, viewId: String, plugin: TwilioFlutterVideoSdkPlugin?) {
        self.frame = frame
        self.viewId = viewId
        self.plugin = plugin
        super.init()
    }
    
    func view() -> UIView {
        print("📺 TwilioVideoPlatformView.view() called for viewId: '\(viewId)'")
        print("   Initial frame: \(frame)")
        
        // Use the frame provided, but fallback to a default if it's zero
        // This ensures the container always has a visible size
        let containerFrame: CGRect
        if frame.width > 0 && frame.height > 0 {
            containerFrame = frame
        } else {
            // Default size if frame is zero (common when Flutter hasn't laid out yet)
            containerFrame = CGRect(x: 0, y: 0, width: 300, height: 400)
            print("   ⚠️ Frame was zero, using default: \(containerFrame)")
        }
        
        // Create a container view that will hold the VideoView
        let container = UIView(frame: containerFrame)
        container.backgroundColor = .black
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.clipsToBounds = true
        self.containerView = container
        
        print("   Container frame: \(container.frame)")
        
        // Get the actual VideoView from the plugin
        if let videoView = plugin?.getVideoView(for: viewId) {
            print("✅ TwilioVideoPlatformView: Found VideoView for viewId: '\(viewId)'")
            print("   VideoView original frame: \(videoView.frame)")
            
            // Configure the video view to fill the container
            videoView.frame = container.bounds
            videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            videoView.contentMode = .scaleAspectFill
            
            // Remove from any previous parent to avoid conflicts
            videoView.removeFromSuperview()
            
            // Add the video view to the container
            container.addSubview(videoView)
            
            // Ensure the view is properly laid out
            videoView.setNeedsLayout()
            videoView.layoutIfNeeded()
            container.setNeedsLayout()
            container.layoutIfNeeded()
            
            print("✅ TwilioVideoPlatformView: VideoView added to container")
            print("   Final VideoView frame: \(videoView.frame)")
            print("   Final Container frame: \(container.frame)")
        } else {
            print("⚠️ TwilioVideoPlatformView: VideoView not found for viewId: '\(viewId)'")
            if let plugin = plugin {
                print("   Available remote views: \(Array(plugin.remoteVideoViews.keys))")
                print("   Local view exists: \(plugin.localVideoView != nil)")
            }
            // Show placeholder with label
            let placeholder = UIView(frame: container.bounds)
            placeholder.backgroundColor = .black
            placeholder.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            
            let label = UILabel(frame: container.bounds)
            label.text = "Waiting for video...\n(viewId: \(viewId))"
            label.textColor = .white
            label.textAlignment = .center
            label.numberOfLines = 0
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            placeholder.addSubview(label)
            
            container.addSubview(placeholder)
        }
        
        return container
    }
}
