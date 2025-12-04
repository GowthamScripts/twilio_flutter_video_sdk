package com.example.twilio_flutter_video_sdk

import android.app.Activity
import android.content.Context
import android.util.Log
import androidx.annotation.NonNull
import com.twilio.video.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** TwilioFlutterVideoSdkPlugin */
class TwilioFlutterVideoSdkPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    Room.Listener,
    Camera2Capturer.Listener {
    
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    
    private var activity: Activity? = null
    private var context: Context? = null
    
    // Twilio Video SDK components
    private var room: Room? = null
    private var localParticipant: LocalParticipant? = null
    private var localVideoTrack: LocalVideoTrack? = null
    private var localAudioTrack: LocalAudioTrack? = null
    private var cameraCapturer: Camera2Capturer? = null
    private var videoView: VideoView? = null
    
    private var isAudioEnabled = true
    private var isVideoEnabled = true
    private var isFrontCamera = true
    
    companion object {
        private const val TAG = "TwilioVideoPlugin"
        private const val METHOD_CHANNEL = "twilio_flutter_video_sdk"
        private const val EVENT_CHANNEL = "twilio_flutter_video_sdk_events"
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
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

            // Initialize camera capturer
            val cameraSource = if (enableFrontCamera) {
                Camera2Capturer.CameraSource.FRONT_CAMERA
            } else {
                Camera2Capturer.CameraSource.BACK_CAMERA
            }

            val activityContext = activity ?: context
            if (activityContext == null) {
                result.error("NO_ACTIVITY", "Activity context is required", null)
                return
            }

            // Create camera capturer
            cameraCapturer = Camera2Capturer(activityContext, cameraSource)
            cameraCapturer?.listener = this

            // Create local video track
            if (enableVideo) {
                val videoConstraints = VideoConstraints.Builder()
                    .build()
                localVideoTrack = LocalVideoTrack.create(
                    activityContext,
                    enableVideo,
                    videoConstraints,
                    cameraCapturer,
                    "local-video-track"
                )
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
                .listener(this)

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

    private fun disconnect(result: Result) {
        try {
            localVideoTrack?.release()
            localAudioTrack?.release()
            cameraCapturer?.stopCapture()
            cameraCapturer = null
            
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
            isFrontCamera = !isFrontCamera
            val newCameraSource = if (isFrontCamera) {
                Camera2Capturer.CameraSource.FRONT_CAMERA
            } else {
                Camera2Capturer.CameraSource.BACK_CAMERA
            }
            
            cameraCapturer?.switchCamera(newCameraSource)
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

    override fun onParticipantEnabledAudioTrack(
        room: Room,
        participant: RemoteParticipant,
        audioTrackPublication: RemoteAudioTrackPublication
    ) {
        sendEvent("audioTrackAdded", mapOf(
            "participantSid" to participant.sid
        ))
    }

    override fun onParticipantDisabledAudioTrack(
        room: Room,
        participant: RemoteParticipant,
        audioTrackPublication: RemoteAudioTrackPublication
    ) {
        sendEvent("audioTrackRemoved", mapOf(
            "participantSid" to participant.sid
        ))
    }

    override fun onParticipantEnabledVideoTrack(
        room: Room,
        participant: RemoteParticipant,
        videoTrackPublication: RemoteVideoTrackPublication
    ) {
        sendEvent("videoTrackAdded", mapOf(
            "track" to mapOf(
                "trackSid" to videoTrackPublication.trackSid,
                "participantSid" to participant.sid,
                "isEnabled" to true
            )
        ))
    }

    override fun onParticipantDisabledVideoTrack(
        room: Room,
        participant: RemoteParticipant,
        videoTrackPublication: RemoteVideoTrackPublication
    ) {
        sendEvent("videoTrackRemoved", mapOf(
            "track" to mapOf(
                "trackSid" to videoTrackPublication.trackSid,
                "participantSid" to participant.sid,
                "isEnabled" to false
            )
        ))
    }

    // Camera2Capturer.Listener implementation
    override fun onFirstFrameAvailable() {
        Log.d(TAG, "First frame available")
    }

    override fun onCameraSwitched() {
        Log.d(TAG, "Camera switched")
    }

    override fun onError(error: String) {
        Log.e(TAG, "Camera error: $error")
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
