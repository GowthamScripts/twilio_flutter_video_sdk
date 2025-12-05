package com.example.twilio_flutter_video_sdk

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import android.Manifest
import com.twilio.video.*
import tvi.webrtc.Camera1Enumerator
import tvi.webrtc.Camera2Enumerator
import tvi.webrtc.CameraEnumerator
import tvi.webrtc.VideoCapturer as WebRtcVideoCapturer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec

/** TwilioFlutterVideoSdkPlugin */
class TwilioFlutterVideoSdkPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    Room.Listener,
    CameraCapturer.Listener,
    Camera2Capturer.Listener {
    
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    
    private var activity: Activity? = null
    private var context: Context? = null
    
    // Twilio Video SDK components
    private var room: Room? = null
    private var localParticipant: LocalParticipant? = null
    private var localVideoTrack: LocalVideoTrack? = null
    private var localAudioTrack: LocalAudioTrack? = null
    private var cameraCapturer: VideoCapturer? = null
    private var localVideoView: VideoView? = null
    
    // Remote video views
    private val remoteVideoViews = mutableMapOf<String, VideoView>()
    private val remoteVideoTracks = mutableMapOf<String, RemoteVideoTrack>()
    
    private var isAudioEnabled = true
    private var isVideoEnabled = true
    private var isFrontCamera = true
    private var currentCameraId: String? = null
    
    companion object {
        private const val TAG = "TwilioVideoPlugin"
        private const val METHOD_CHANNEL = "twilio_flutter_video_sdk"
        private const val EVENT_CHANNEL = "twilio_flutter_video_sdk_events"
    }
    
    // Helper: find Twilio/WebRTC device name for requested facing direction
    private fun findDeviceNameForFacing(context: Context, preferFront: Boolean): String? {
        val enumerator: CameraEnumerator = if (Camera2Enumerator.isSupported(context)) {
            Camera2Enumerator(context)
        } else {
            Camera1Enumerator()
        }
        
        val deviceNames = enumerator.deviceNames
        Log.d(TAG, "Available WebRTC device names: ${deviceNames.joinToString()}")
        
        // Prefer front/back as requested
        for (name in deviceNames) {
            if (enumerator.isFrontFacing(name) && preferFront) {
                Log.d(TAG, "Found front-facing device: $name")
                return name
            }
            if (!enumerator.isFrontFacing(name) && !preferFront) {
                Log.d(TAG, "Found back-facing device: $name")
                return name
            }
        }
        
        // Fallback: return first available device name
        val fallback = if (deviceNames.isNotEmpty()) deviceNames[0] else null
        if (fallback != null) {
            Log.d(TAG, "Using fallback device: $fallback")
        }
        return fallback
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        this.flutterPluginBinding = flutterPluginBinding
        
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, METHOD_CHANNEL)
        channel.setMethodCallHandler(this)
        
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
        
        // Register PlatformView factory
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "twilio_video_view",
            TwilioVideoViewFactory(this)
        )
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "joinRoom" -> {
                joinRoom(call, result)
            }
            "disconnect" -> {
                disconnect(result)
            }
            "setMuted" -> {
                val muted = call.argument<Boolean>("muted") ?: false
                setMuted(muted, result)
            }
            "setVideoEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                setVideoEnabled(enabled, result)
            }
            "switchCamera" -> {
                switchCamera(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun joinRoom(call: MethodCall, result: Result) {
        try {
            val accessToken = call.argument<String>("accessToken")
            val roomName = call.argument<String>("roomName")
            val enableAudio = call.argument<Boolean>("enableAudio") ?: true
            val enableVideo = call.argument<Boolean>("enableVideo") ?: true
            val enableFrontCamera = call.argument<Boolean>("enableFrontCamera") ?: true

            if (accessToken == null || roomName == null) {
                result.error("INVALID_ARGUMENTS", "Access token and room name are required", null)
                return
            }

            isAudioEnabled = enableAudio
            isVideoEnabled = enableVideo
            isFrontCamera = enableFrontCamera

            val activityContext = activity ?: context
            if (activityContext == null) {
                result.error("NO_ACTIVITY", "Activity context is required", null)
                return
            }

            // Check camera permission
            if (ContextCompat.checkSelfPermission(activityContext, Manifest.permission.CAMERA)
                != PackageManager.PERMISSION_GRANTED) {
                result.error("PERMISSION_DENIED", "Camera permission not granted", null)
                return
            }

            // Find Twilio/WebRTC device name for requested facing direction
            var deviceName: String? = null
            if (enableVideo) {
                deviceName = findDeviceNameForFacing(activityContext, enableFrontCamera)
                
                if (deviceName.isNullOrEmpty()) {
                    result.error("NO_CAMERA", "No camera device available", null)
                    return
                }
                
                currentCameraId = deviceName
                Log.d(TAG, "Using Twilio/WebRTC device name: $deviceName")
            }

            // Create camera capturer using Twilio's camera classes
            if (enableVideo && deviceName != null) {
                // Use Camera2Capturer if supported, otherwise use CameraCapturer
                cameraCapturer = if (Camera2Capturer.isSupported(activityContext)) {
                    Camera2Capturer(activityContext, deviceName, this)
                } else {
                    CameraCapturer(activityContext, deviceName, this)
                }
                
                // Attempt to cast the Twilio capturer to tvi.webrtc.VideoCapturer
                // (Fix B: handles type mismatch between com.twilio.video.VideoCapturer and tvi.webrtc.VideoCapturer)
                val webRtcCapturer: WebRtcVideoCapturer? = when (cameraCapturer) {
                    is Camera2Capturer -> (cameraCapturer as? Any) as? WebRtcVideoCapturer
                    is CameraCapturer -> (cameraCapturer as? Any) as? WebRtcVideoCapturer
                    else -> null
                }
                
                if (webRtcCapturer == null) {
                    result.error("CAPTURER_CAST_FAILED", "Could not get tvi.webrtc.VideoCapturer from Twilio capturer", null)
                    return
                }
                
                // Create local video track with the WebRTC capturer
                localVideoTrack = LocalVideoTrack.create(
                    activityContext,
                    enableVideo,
                    webRtcCapturer,
                    "local-video-track"
                )
                
                // Setup local video view
                setupLocalVideoView(activityContext)
            }

            // Create local audio track
            if (enableAudio) {
                localAudioTrack = LocalAudioTrack.create(
                    activityContext,
                    enableAudio,
                    "local-audio-track"
                )
            }

            // Build connect options
            val connectOptionsBuilder = ConnectOptions.Builder(accessToken)
                .roomName(roomName)

            if (enableAudio && localAudioTrack != null) {
                connectOptionsBuilder.audioTracks(listOf(localAudioTrack!!))
            }

            if (enableVideo && localVideoTrack != null) {
                connectOptionsBuilder.videoTracks(listOf(localVideoTrack!!))
            }

            // Connect to room
            room = Video.connect(activityContext, connectOptionsBuilder.build(), this)
            
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "Error joining room: ${e.message}", e)
            result.error("JOIN_ROOM_ERROR", e.message, null)
        }
    }

    private fun setupLocalVideoView(context: Context) {
        val activityContext = activity ?: context
        if (activityContext == null || localVideoTrack == null) return
        
        val localView = VideoView(activityContext)
        localVideoTrack?.addSink(localView)
        localVideoView = localView
    }
    
    fun getVideoView(viewId: String): VideoView? {
        return if (viewId == "0") {
            localVideoView
        } else {
            remoteVideoViews[viewId]
        }
    }

    private fun disconnect(result: Result) {
        try {
            localVideoTrack?.release()
            localAudioTrack?.release()
            cameraCapturer?.stopCapture()
            cameraCapturer = null
            currentCameraId = null
            
            // Clean up video views
            localVideoView = null
            remoteVideoViews.clear()
            remoteVideoTracks.clear()
            
            room?.disconnect()
            room = null
            localParticipant = null
            
            sendEvent("disconnected", emptyMap())
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "Error disconnecting: ${e.message}", e)
            result.error("DISCONNECT_ERROR", e.message, null)
        }
    }

    private fun setMuted(muted: Boolean, result: Result) {
        try {
            isAudioEnabled = !muted
            localAudioTrack?.enable(!muted)
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "Error setting muted: ${e.message}", e)
            result.error("SET_MUTED_ERROR", e.message, null)
        }
    }

    private fun setVideoEnabled(enabled: Boolean, result: Result) {
        try {
            isVideoEnabled = enabled
            localVideoTrack?.enable(enabled)
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "Error setting video enabled: ${e.message}", e)
            result.error("SET_VIDEO_ENABLED_ERROR", e.message, null)
        }
    }

    private fun switchCamera(result: Result) {
        try {
            val capturer = cameraCapturer  // local snapshot for safe smart-casting

            if (capturer == null) {
                result.error("SWITCH_CAMERA_ERROR", "Camera capturer not initialized", null)
                return
            }

            val activityContext = activity ?: context
            if (activityContext == null) {
                result.error("SWITCH_CAMERA_ERROR", "Activity context is required", null)
                return
            }

            // Toggle camera facing direction flag (keep state)
            isFrontCamera = !isFrontCamera

            // Find new device name for the new facing direction
            val newDeviceName = findDeviceNameForFacing(activityContext, isFrontCamera)
            
            if (newDeviceName.isNullOrEmpty()) {
                result.error("SWITCH_CAMERA_ERROR", "No camera available for switching", null)
                return
            }

            when (capturer) {
                is Camera2Capturer -> {
                    // capturer is already typed as Camera2Capturer
                    capturer.switchCamera(newDeviceName)
                }
                is CameraCapturer -> {
                    // capturer is already typed as CameraCapturer (legacy)
                    capturer.switchCamera(newDeviceName)
                }
                else -> {
                    result.error("SWITCH_CAMERA_ERROR", "Unsupported camera capturer type", null)
                    return
                }
            }
            
            currentCameraId = newDeviceName
            Log.d(TAG, "Switched camera to device: $newDeviceName")
            
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "Error switching camera: ${e.message}", e)
            result.error("SWITCH_CAMERA_ERROR", e.message, null)
        }
    }

    private fun sendEvent(event: String, data: Map<String, Any>) {
        val eventData = mapOf("event" to event) + data
        eventSink?.success(eventData)
    }

    // Room.Listener implementation
    override fun onConnected(room: Room) {
        Log.d(TAG, "Connected to room: ${room.name}")
        this.room = room
        localParticipant = room.localParticipant
        
        sendEvent("connected", mapOf("roomName" to (room.name ?: "")))
    }

    override fun onConnectFailure(room: Room, error: TwilioException) {
        Log.e(TAG, "Failed to connect to room: ${error.message}")
        sendEvent("connectionFailure", mapOf("error" to (error.message ?: "Unknown error")))
    }

    override fun onDisconnected(room: Room, error: TwilioException?) {
        Log.d(TAG, "Disconnected from room: ${room.name}")
        sendEvent("disconnected", emptyMap())
    }

    override fun onParticipantConnected(room: Room, participant: RemoteParticipant) {
        Log.d(TAG, "Participant connected: ${participant.identity}")
        
        // Attach listener to participant
        participant.setListener(object : RemoteParticipant.Listener {
            override fun onVideoTrackSubscribed(
                participant: RemoteParticipant,
                publication: RemoteVideoTrackPublication,
                remoteVideoTrack: RemoteVideoTrack
            ) {
                val activityContext = activity ?: context
                if (activityContext == null) return
                
                val remoteView = VideoView(activityContext)
                remoteVideoTrack.addSink(remoteView)
                remoteVideoViews[participant.sid] = remoteView
                remoteVideoTracks[participant.sid] = remoteVideoTrack
                
                sendEvent("videoTrackAdded", mapOf(
                    "track" to mapOf(
                        "trackSid" to publication.trackSid,
                        "participantSid" to participant.sid,
                        "isEnabled" to true
                    )
                ))
            }

            override fun onVideoTrackUnsubscribed(
                participant: RemoteParticipant,
                publication: RemoteVideoTrackPublication,
                remoteVideoTrack: RemoteVideoTrack
            ) {
                val remoteView = remoteVideoViews.remove(participant.sid)
                remoteView?.let { remoteVideoTrack.removeSink(it) }
                remoteVideoTracks.remove(participant.sid)

                sendEvent("videoTrackRemoved", mapOf(
                    "track" to mapOf(
                        "trackSid" to publication.trackSid,
                        "participantSid" to participant.sid,
                        "isEnabled" to false
                    )
                ))
            }

            // Implement other track events if needed
            override fun onAudioTrackSubscribed(
                participant: RemoteParticipant,
                publication: RemoteAudioTrackPublication,
                remoteAudioTrack: RemoteAudioTrack
            ) {
                sendEvent("audioTrackAdded", mapOf("participantSid" to participant.sid))
            }

            override fun onAudioTrackUnsubscribed(
                participant: RemoteParticipant,
                publication: RemoteAudioTrackPublication,
                remoteAudioTrack: RemoteAudioTrack
            ) {
                sendEvent("audioTrackRemoved", mapOf("participantSid" to participant.sid))
            }

            override fun onAudioTrackPublished(
                participant: RemoteParticipant,
                publication: RemoteAudioTrackPublication
            ) {}
            
            override fun onAudioTrackUnpublished(
                participant: RemoteParticipant,
                publication: RemoteAudioTrackPublication
            ) {}
            
            override fun onVideoTrackPublished(
                participant: RemoteParticipant,
                publication: RemoteVideoTrackPublication
            ) {}
            
            override fun onVideoTrackUnpublished(
                participant: RemoteParticipant,
                publication: RemoteVideoTrackPublication
            ) {}
            
            override fun onDataTrackPublished(
                participant: RemoteParticipant,
                publication: RemoteDataTrackPublication
            ) {}
            
            override fun onDataTrackUnpublished(
                participant: RemoteParticipant,
                publication: RemoteDataTrackPublication
            ) {}
            
            override fun onNetworkQualityLevelChanged(
                participant: RemoteParticipant,
                networkQualityLevel: NetworkQualityLevel
            ) {}
            
            override fun onDataTrackSubscribed(
                participant: RemoteParticipant,
                publication: RemoteDataTrackPublication,
                remoteDataTrack: RemoteDataTrack
            ) {}
            
            override fun onDataTrackUnsubscribed(
                participant: RemoteParticipant,
                publication: RemoteDataTrackPublication,
                remoteDataTrack: RemoteDataTrack
            ) {}
            
            override fun onAudioTrackSubscriptionFailed(
                participant: RemoteParticipant,
                publication: RemoteAudioTrackPublication,
                twilioException: TwilioException
            ) {}
            
            override fun onVideoTrackSubscriptionFailed(
                participant: RemoteParticipant,
                publication: RemoteVideoTrackPublication,
                twilioException: TwilioException
            ) {}
            
            override fun onDataTrackSubscriptionFailed(
                participant: RemoteParticipant,
                publication: RemoteDataTrackPublication,
                twilioException: TwilioException
            ) {}
            
            override fun onAudioTrackEnabled(
                participant: RemoteParticipant,
                publication: RemoteAudioTrackPublication
            ) {
                // Optional: handle audio track enabled event
            }
            
            override fun onAudioTrackDisabled(
                participant: RemoteParticipant,
                publication: RemoteAudioTrackPublication
            ) {
                // Optional: handle audio track disabled event
            }
            
            override fun onVideoTrackEnabled(
                participant: RemoteParticipant,
                publication: RemoteVideoTrackPublication
            ) {
                // Optional: handle video track enabled event
            }
            
            override fun onVideoTrackDisabled(
                participant: RemoteParticipant,
                publication: RemoteVideoTrackPublication
            ) {
                // Optional: handle video track disabled event
            }
        })

        sendEvent("participantConnected", mapOf(
            "participant" to mapOf(
                "sid" to participant.sid,
                "identity" to (participant.identity ?: ""),
                "isAudioEnabled" to true,
                "isVideoEnabled" to true
            )
        ))
    }

    override fun onParticipantDisconnected(room: Room, participant: RemoteParticipant) {
        Log.d(TAG, "Participant disconnected: ${participant.identity}")
        
        // Clean up remote video view
        val remoteView = remoteVideoViews.remove(participant.sid)
        remoteView?.let { view ->
            // Remove sink from track if it exists
            remoteVideoTracks[participant.sid]?.removeSink(view)
        }
        remoteVideoTracks.remove(participant.sid)
        
        sendEvent("participantDisconnected", mapOf(
            "participant" to mapOf(
                "sid" to participant.sid,
                "identity" to (participant.identity ?: ""),
                "isAudioEnabled" to false,
                "isVideoEnabled" to false
            )
        ))
    }

    override fun onRecordingStarted(room: Room) {}
    override fun onRecordingStopped(room: Room) {}
    override fun onDominantSpeakerChanged(room: Room, remoteParticipant: RemoteParticipant?) {
        if (remoteParticipant != null) {
            sendEvent("dominantSpeakerChanged", mapOf(
                "participantSid" to remoteParticipant.sid
            ))
        }
    }

    override fun onReconnecting(room: Room, error: TwilioException) {
        Log.d(TAG, "Reconnecting to room...")
        sendEvent("reconnecting", emptyMap())
    }

    override fun onReconnected(room: Room) {
        Log.d(TAG, "Reconnected to room")
        sendEvent("reconnected", emptyMap())
    }

    // CameraCapturer.Listener and Camera2Capturer.Listener implementation
    override fun onFirstFrameAvailable() {
        Log.d(TAG, "First frame available")
    }

    override fun onCameraSwitched(cameraId: String) {
        Log.d(TAG, "Camera switched: $cameraId")
    }

    // From CameraCapturer.Listener
    override fun onError(errorCode: Int) {
        Log.e(TAG, "CameraCapturer error: $errorCode")
    }

    // From Camera2Capturer.Listener
    override fun onError(error: Camera2Capturer.Exception) {
        Log.e(TAG, "Camera2Capturer error: ${error.message}")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}

// PlatformView Factory for Android
class TwilioVideoViewFactory(private val plugin: TwilioFlutterVideoSdkPlugin) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        // Extract viewId from creationParams
        var viewIdString = "0" // default to local
        if (args is Map<*, *>) {
            val viewIdArg = args["viewId"]
            if (viewIdArg is String) {
                viewIdString = viewIdArg
            }
        }
        
        return TwilioVideoPlatformView(context, viewIdString, plugin)
    }
}

// PlatformView implementation for Android
class TwilioVideoPlatformView(
    private val context: Context,
    private val viewId: String,
    private val plugin: TwilioFlutterVideoSdkPlugin
) : PlatformView {
    
    private var videoView: VideoView? = null
    
    override fun getView(): android.view.View {
        // Get the actual VideoView from the plugin
        videoView = plugin.getVideoView(viewId)
        
        if (videoView != null) {
            return videoView!!
        }
        
        // Return placeholder if view not ready yet
        val placeholder = android.view.View(context)
        placeholder.setBackgroundColor(android.graphics.Color.BLACK)
        return placeholder
    }
    
    override fun dispose() {
        // View disposal is handled by the plugin
    }
}
