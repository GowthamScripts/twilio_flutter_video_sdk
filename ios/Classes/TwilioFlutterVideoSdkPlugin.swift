import Flutter
import UIKit
import TwilioVideo
import AVFoundation

public class TwilioFlutterVideoSdkPlugin: NSObject, FlutterPlugin {
    
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    
    private var room: Room?
    private var camera: CameraSource?
    private var localVideoTrack: LocalVideoTrack?
    private var localAudioTrack: LocalAudioTrack?
    
    private var isAudioEnabled = true
    private var isVideoEnabled = true
    private var isFrontCamera = true
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: "twilio_flutter_video_sdk", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "twilio_flutter_video_sdk_events", binaryMessenger: registrar.messenger())
        
        let instance = TwilioFlutterVideoSdkPlugin()
        instance.methodChannel = methodChannel
        instance.eventChannel = eventChannel
        
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
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
            camera = CameraSource(delegate: self, options: options)
            
            // Create local video track
            if enableVideo, let camera = camera {
                localVideoTrack = LocalVideoTrack(source: camera, enabled: true, name: "local-video-track")
                
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
        localVideoTrack = nil
        localAudioTrack = nil
        camera = nil
        room = nil
        
        sendEvent(event: "disconnected", data: [:])
        result(nil)
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

// MARK: - RoomDelegate
extension TwilioFlutterVideoSdkPlugin: RoomDelegate {
    public func roomDidConnect(room: Room) {
        sendEvent(event: "connected", data: ["roomName": room.name])
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
        sendEvent(event: "participantConnected", data: [
            "participant": [
                "sid": participant.sid,
                "identity": participant.identity ?? "",
                "isAudioEnabled": true,
                "isVideoEnabled": true
            ]
        ])
    }
    
    public func participantDidDisconnect(room: Room, participant: RemoteParticipant) {
        sendEvent(event: "participantDisconnected", data: [
            "participant": [
                "sid": participant.sid,
                "identity": participant.identity ?? "",
                "isAudioEnabled": false,
                "isVideoEnabled": false
            ]
        ])
    }
    
    public func participant(participant: RemoteParticipant, didEnableVideoTrack videoTrack: RemoteVideoTrackPublication) {
        sendEvent(event: "videoTrackAdded", data: [
            "track": [
                "trackSid": videoTrack.trackSid,
                "participantSid": participant.sid,
                "isEnabled": true
            ]
        ])
    }
    
    public func participant(participant: RemoteParticipant, didDisableVideoTrack videoTrack: RemoteVideoTrackPublication) {
        sendEvent(event: "videoTrackRemoved", data: [
            "track": [
                "trackSid": videoTrack.trackSid,
                "participantSid": participant.sid,
                "isEnabled": false
            ]
        ])
    }
    
    public func participant(participant: RemoteParticipant, didEnableAudioTrack audioTrack: RemoteAudioTrackPublication) {
        sendEvent(event: "audioTrackAdded", data: [
            "participantSid": participant.sid
        ])
    }
    
    public func participant(participant: RemoteParticipant, didDisableAudioTrack audioTrack: RemoteAudioTrackPublication) {
        sendEvent(event: "audioTrackRemoved", data: [
            "participantSid": participant.sid
        ])
    }
    
    public func dominantSpeakerDidChange(room: Room, participant: RemoteParticipant?) {
        if let participant = participant {
            sendEvent(event: "dominantSpeakerChanged", data: [
                "participantSid": participant.sid
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
