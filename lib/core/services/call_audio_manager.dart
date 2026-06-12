// =============================================================================
// Enhanced Call Audio Manager
// - Earpiece audio routing for caller
// - System default ringtone with loudspeaker for receiver
// - 30-second timeout with auto-reject
// - Audio focus management
// =============================================================================

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:whoxa/utils/logger.dart';
import 'package:whoxa/core/services/call_notification_manager.dart';

enum AudioMode {
  normal, // Default mode
  ringtone, // Playing ringtone on loudspeaker
  calling, // Caller - audio through earpiece
  inCall, // Connected call - default routing
}

class CallAudioManager {
  static final CallAudioManager _instance = CallAudioManager._internal();
  static CallAudioManager get instance => _instance;
  CallAudioManager._internal();

  final _logger = ConsoleAppLogger.forModule('CallAudioManager');

  // Audio players
  AudioPlayer? _ringtonePlayer;
  AudioPlayer? _callerTonePlayer;

  // State management
  AudioMode _currentMode = AudioMode.normal;
  bool _isInitialized = false;
  Timer? _timeoutTimer;

  // Callbacks
  VoidCallback? onCallTimeout;

  // Audio focus channel for native audio management
  static const platform = MethodChannel('primocys.call.audio');

  /// Initialize the audio manager
  Future<void> initialize() async {
    try {
      _logger.i('🎵 CallAudioManager: Initializing...');

      // Initialize audio players
      _ringtonePlayer = AudioPlayer();
      _callerTonePlayer = AudioPlayer();

      // Set up platform method call handler
      platform.setMethodCallHandler(_handleMethodCall);

      _isInitialized = true;
      _logger.i('✅ CallAudioManager: Initialized successfully');
    } catch (e) {
      _logger.e('❌ CallAudioManager: Failed to initialize: $e');
      rethrow;
    }
  }

  /// Handle platform method calls
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAudioFocusChange':
        final int focusChange = call.arguments;
        _handleAudioFocusChange(focusChange);
        break;
      default:
        _logger.w('⚠️ Unhandled method call: ${call.method}');
    }
  }

  /// Handle audio focus changes
  void _handleAudioFocusChange(int focusChange) {
    _logger.d('🎵 Audio focus changed: $focusChange');

    switch (focusChange) {
      case -3: // AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK
      case -2: // AUDIOFOCUS_LOSS_TRANSIENT
        // Pause/duck audio
        _pauseCurrentAudio();
        break;
      case -1: // AUDIOFOCUS_LOSS
        // Stop all audio
        _stopAllAudio();
        break;
      case 1: // AUDIOFOCUS_GAIN
        // Resume audio if needed
        _resumeCurrentAudio();
        break;
    }
  }

  /// Start playing device default ringtone for incoming calls (receiver side)
  /// Uses device default ringtone via loudspeaker, stops on accept/reject
  Future<void> startIncomingCallRingtone() async {
    if (!_isInitialized) await initialize();

    try {
      _logger.i('🎵 Starting device default ringtone for incoming call...');

      // Set audio mode to ringtone
      _currentMode = AudioMode.ringtone;

      // Request audio focus and configure for ringtone playback
      await _requestAudioFocus();
      await _configureAudioForRingtone();

      // Use system ringtone via platform channel (Android native implementation)
      bool ringtoneStarted = false;

      try {
        await platform.invokeMethod('playSystemRingtone');
        ringtoneStarted = true;
        _logger.i('✅ System default ringtone started via platform channel');
      } catch (e) {
        _logger.w('⚠️ Platform channel system ringtone failed: $e');

        // Fallback: Try custom ringtone via platform as backup
        try {
          await platform.invokeMethod('playCustomCallRingtone');
          ringtoneStarted = true;
          _logger.i('✅ Fallback to platform custom ringtone');
        } catch (e2) {
          _logger.w('⚠️ Platform custom ringtone fallback failed: $e2');
        }
      }

      if (ringtoneStarted) {
        _logger.i('✅ Device default ringtone started successfully');
        // Start 30-second timeout
        _startCallTimeout();
      } else {
        _logger.e('❌ All ringtone methods failed - no audio will play');
      }
    } catch (e) {
      _logger.e('❌ Failed to start device default ringtone: $e');
    }
  }

  /// Start caller tone (earpiece for audio calls, speaker for video calls)  
  /// Uses phone-ringtone-emitting-from-ear-piece.mp3 from assets when user makes outgoing call
  Future<void> startCallerTone({bool isVideoCall = false}) async {
    if (!_isInitialized) {
      _logger.w('🎵 Audio manager not initialized, initializing now...');
      await initialize();
    }

    if (_callerTonePlayer == null) {
      _logger.e('❌ Caller tone player is null after initialization!');
      return;
    }

    try {
      // CRITICAL: Check if caller tone is already playing to prevent "Loading interrupted"
      if (_callerTonePlayer!.playing && _currentMode == AudioMode.calling) {
        _logger.i(
          '🎵 Caller tone already playing - skipping duplicate start call to prevent "Loading interrupted"',
        );
        return;
      }

      _logger.i(
        '🎵 Starting phone ringtone for ${isVideoCall ? "speaker (video call)" : "earpiece (audio call)"}...',
      );

      // Set audio mode to calling
      _currentMode = AudioMode.calling;

      // SENIOR DEV FIX: Temporarily release WebRTC audio session for ringtone
      await _releaseWebRTCAudioSession();

      // CRITICAL: Request audio focus first
      await _requestAudioFocus();

      // Configure audio routing based on call type
      await _configureAudioForEarpiece(isVideoCall: isVideoCall);

      // CRITICAL: Stop any existing ringtone first (only if not already playing to prevent interruption)
      if (_callerTonePlayer!.playing) {
        _logger.w('⚠️ Stopping existing caller tone to start fresh (this may cause interruption)');
        await _callerTonePlayer!.stop();
        await _callerTonePlayer!.seek(Duration.zero);
        // Add delay to prevent race condition
        await Future.delayed(Duration(milliseconds: 100));
      }

      // Try multiple approaches for maximum reliability
      bool ringtoneStarted = false;

      // First try: Load and play phone ringtone from assets - specifically designed for earpiece
      try {
        _logger.i('🎵 Attempting to load phone ringtone asset...');
        await _callerTonePlayer!.setAsset(
          'assets/audio/phone-ringtone-emitting-from-ear-piece.mp3',
        );
        _logger.i('🎵 Asset loaded, setting loop mode...');
        await _callerTonePlayer!.setLoopMode(LoopMode.all);

        // Set appropriate volume based on audio routing
        final volume =
            isVideoCall
                ? 0.8
                : 0.9; // Slightly lower for speaker, higher for earpiece
        _logger.i('🎵 Setting volume to $volume...');
        await _callerTonePlayer!.setVolume(volume);

        // For audio calls, just_audio will use earpiece when WebRTC routing is configured
        // The Helper.setSpeakerphoneOn(false) call in _configureAudioForEarpiece handles the routing

        _logger.i('🎵 Starting audio playback...');
        await _callerTonePlayer!.play();
        ringtoneStarted = true;
        _logger.i(
          '✅ Phone ringtone from assets started successfully (earpiece: ${!isVideoCall})',
        );
      } catch (assetError, stackTrace) {
        _logger.e('❌ Asset phone ringtone failed: $assetError');
        _logger.e('Stack trace: $stackTrace');
      }

      // Second try: Use system ringtone through platform as backup if asset failed
      if (!ringtoneStarted) {
        try {
          await _playPhoneRingtoneViaPlatform(isVideoCall: isVideoCall);
          ringtoneStarted = true;
          _logger.i('✅ Phone ringtone via platform started successfully');
        } catch (platformError) {
          _logger.w('⚠️ Platform phone ringtone failed: $platformError');
        }
      }

      // Third try: Use original caller tone asset as final fallback
      if (!ringtoneStarted) {
        try {
          _logger.i('🎵 Attempting fallback caller tone asset...');
          await _callerTonePlayer!.setAsset('assets/audio/caller_tone.mp3');
          await _callerTonePlayer!.setLoopMode(LoopMode.all);
          await _callerTonePlayer!.setVolume(0.8);
          await _callerTonePlayer!.play();
          ringtoneStarted = true;
          _logger.i('✅ Fallback caller tone started');
        } catch (fallbackError, stackTrace) {
          _logger.e('❌ Fallback caller tone failed: $fallbackError');
          _logger.e('Stack trace: $stackTrace');
        }
      }

      if (ringtoneStarted) {
        // Start 30-second timeout
        _startCallTimeout();
        _logger.i('✅ Phone ringtone started successfully');
      } else {
        // SENIOR DEV FALLBACK: Use platform-native audio as last resort
        _logger.w('⚠️ All just_audio methods failed, trying platform-native fallback...');
        await _tryPlatformNativeRingtone(isVideoCall: isVideoCall);
      }
    } catch (e) {
      _logger.e('❌ Failed to start phone ringtone: $e');
    }
  }

  /// Configure audio routing for ringtone (loudspeaker)
  /// Used for incoming call ringtones - plays through loudspeaker
  Future<void> _configureAudioForRingtone() async {
    try {
      // Ensure proper audio session first
      await _ensureProperAudioSession();

      // Set speakerphone ON for ringtone with Bluetooth preference
      await Helper.setSpeakerphoneOnButPreferBluetooth();

      // Also call native configuration for ringtone
      try {
        await platform.invokeMethod('configureAudioForRingtone');
        _logger.d('🎵 Native ringtone audio configuration applied');
      } catch (nativeError) {
        _logger.w('⚠️ Native ringtone configuration failed: $nativeError');
      }

      _logger.d(
        '🎵 Audio configured for ringtone (loudspeaker with Bluetooth preference)',
      );
    } catch (e) {
      _logger.e('❌ Failed to configure audio for ringtone: $e');
    }
  }

  /// Configure audio routing for earpiece (caller side)
  /// Used for outgoing call tones - plays through earpiece for audio calls, speaker for video calls
  Future<void> _configureAudioForEarpiece({bool isVideoCall = false}) async {
    try {
      // CRITICAL: First ensure audio session is properly configured
      await _ensureProperAudioSession();

      // For video calls, use speaker; for audio calls, use earpiece
      final useSpeaker = isVideoCall;

      if (useSpeaker) {
        // For video calls - use speaker with Bluetooth preference
        await Helper.setSpeakerphoneOnButPreferBluetooth();
        _logger.d(
          '🎵 Audio configured for speaker (video call) with Bluetooth preference',
        );
      } else {
        // For audio calls - explicitly force earpiece routing
        await _forceEarpieceRouting();
        _logger.d(
          '🎵 Audio configured for earpiece (audio call) using forced routing',
        );
      }
    } catch (e) {
      _logger.e('❌ Failed to configure audio routing: $e');
      // Fallback to basic WebRTC routing
      try {
        await Helper.setSpeakerphoneOn(isVideoCall);
        _logger.w('⚠️ Using fallback WebRTC routing');
      } catch (fallbackError) {
        _logger.e('❌ Fallback routing also failed: $fallbackError');
      }
    }
  }

  /// Ensure proper audio session configuration
  Future<void> _ensureProperAudioSession() async {
    try {
      // For iOS: Ensure audio session is properly configured
      await Helper.ensureAudioSession();
      _logger.d('🎵 Audio session ensured');
    } catch (e) {
      _logger.w(
        '⚠️ Failed to ensure audio session (may not be available on this platform): $e',
      );
    }
  }

  /// Force earpiece routing for audio calls
  Future<void> _forceEarpieceRouting() async {
    try {
      // Method 1: Use WebRTC's standard earpiece routing
      await Helper.setSpeakerphoneOn(false);

      // Method 2: Try to select earpiece device if available
      try {
        final devices = await Helper.enumerateDevices('audiooutput');
        final earpieceDevice = devices.firstWhere(
          (device) =>
              device.label.toLowerCase().contains('earpiece') ||
              device.label.toLowerCase().contains('receiver'),
          orElse: () => devices.first,
        );

        if (earpieceDevice.deviceId.isNotEmpty) {
          await Helper.selectAudioOutput(earpieceDevice.deviceId);
          _logger.d('🎵 Selected earpiece device: ${earpieceDevice.label}');
        }
      } catch (deviceError) {
        _logger.w('⚠️ Could not select specific earpiece device: $deviceError');
      }

      // Method 3: Call native platform methods as backup
      try {
        await platform.invokeMethod('configureAudioForEarpiece');
        _logger.d('🎵 Native earpiece configuration applied');
      } catch (nativeError) {
        _logger.w('⚠️ Native earpiece configuration failed: $nativeError');
      }

      _logger.d('🎵 Earpiece routing forced successfully');
    } catch (e) {
      _logger.e('❌ Failed to force earpiece routing: $e');
      rethrow;
    }
  }

  /// 🚀 FINAL SOLUTION: WebRTC-Native Audio Configuration
  Future<void> configureAudioForCall({bool useSpeaker = false}) async {
    try {
      _logger.i(
        '🚀 FINAL: WebRTC-native call audio configuration (speaker: $useSpeaker)',
      );

      // Stop any playing tones
      await _stopAllAudio();

      // Set audio mode to in-call
      _currentMode = AudioMode.inCall;

      // 🎯 KEY: Use WebRTC-native audio preparation
      await _prepareAudioForWebRTC(isVideoCall: useSpeaker);

      // 🎯 KEY: Set speaker state via research-based WebRTC-native control
      try {
        _logger.i(
          '🚀 RESEARCH-BASED: Starting WebRTC-native speaker control (${useSpeaker ? "SPEAKER" : "EARPIECE"})',
        );

        final result = await platform.invokeMethod('setSpeakerphone', {
          'enabled': useSpeaker,
        });

        // Handle verification result from iOS
        if (result is Map) {
          final message = result['message'] as String?;
          final expectedSpeaker = result['expectedSpeaker'] as bool?;
          final actualSpeaker = result['actualSpeaker'] as bool?;
          final portType = result['portType'] as String?;

          _logger.i(
            message ?? '🔍 RESEARCH-BASED VERIFICATION: Result received',
          );

          if (expectedSpeaker != null && actualSpeaker != null) {
            if (expectedSpeaker == actualSpeaker) {
              _logger.i(
                '✅ RESEARCH-BASED VERIFICATION PASSED: Audio route is correct (Port: $portType)',
              );
            } else {
              _logger.w(
                '⚠️ RESEARCH-BASED VERIFICATION FAILED: Audio route mismatch! Expected=${expectedSpeaker ? "SPEAKER" : "EARPIECE"}, Got=${actualSpeaker ? "SPEAKER" : "EARPIECE"}',
              );

              // Trigger recovery mechanism
              _logger.i('🔧 RESEARCH-BASED RECOVERY: Attempting fallback...');
              await _performSpeakerRecovery(useSpeaker);
            }
          }
        } else {
          _logger.i(
            '🎯 WebRTC-native speaker control: ${useSpeaker ? "SPEAKER" : "EARPIECE"} (Legacy response)',
          );
        }
      } catch (e) {
        _logger.w('⚠️ Research-based WebRTC-native speaker control failed: $e');

        // Fallback to flutter_webrtc Helper as backup
        try {
          await Helper.setSpeakerphoneOn(useSpeaker);
          _logger.d('🔄 Fallback to flutter_webrtc Helper successful');
        } catch (fallbackError) {
          _logger.e(
            '❌ Fallback to flutter_webrtc Helper also failed: $fallbackError',
          );
        }
      }

      _logger.i('✅ FINAL: WebRTC-native call audio configuration completed');
    } catch (e) {
      _logger.e('❌ FINAL: WebRTC-native call audio configuration failed: $e');

      // Emergency fallback
      try {
        _logger.w('🚨 Emergency audio configuration fallback');
        await Helper.setSpeakerphoneOn(useSpeaker);
        await platform.invokeMethod('setSpeakerphone', {'enabled': useSpeaker});
      } catch (fallbackError) {
        _logger.e(
          '❌ Emergency audio configuration fallback failed: $fallbackError',
        );
      }
    }
  }

  /// Prepare iOS audio session for WebRTC compatibility
  Future<void> _prepareAudioForWebRTC({bool isVideoCall = false}) async {
    try {
      // FIXED: Allow multiple preparations for subsequent calls
      final success = await platform.invokeMethod('prepareAudioForWebRTC', {
        'isVideoCall': isVideoCall,
      });
      if (success == true) {
        _logger.i(
          '✅ iOS audio session prepared for WebRTC (Video: $isVideoCall)',
        );
      } else {
        _logger.e('❌ Failed to prepare iOS audio session for WebRTC');
      }
    } catch (e) {
      _logger.w(
        '⚠️ WebRTC audio preparation not available (may not be iOS): $e',
      );
    }
  }

  /// Request audio focus from the system
  Future<void> _requestAudioFocus() async {
    try {
      // Audio focus is automatically handled by just_audio and WebRTC
      _logger.d('🎵 Audio focus handled automatically by just_audio');
    } catch (e) {
      _logger.e('❌ Failed to handle audio focus: $e');
    }
  }

  /// Release audio focus
  Future<void> _releaseAudioFocus() async {
    try {
      // Audio focus release is automatically handled by just_audio and WebRTC
      _logger.d('🎵 Audio focus release handled automatically by just_audio');
    } catch (e) {
      _logger.e('❌ Failed to handle audio focus release: $e');
    }
  }

  /// Start 30-second call timeout
  void _startCallTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(Duration(seconds: 30), () {
      _logger.w('⏰ Call timeout reached - auto-rejecting');
      onCallTimeout?.call();
    });
  }

  /// Cancel call timeout
  void _cancelCallTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  /// Stop system ringtone
  Future<void> _stopSystemRingtone() async {
    try {
      if (_ringtonePlayer?.playing == true) {
        await _ringtonePlayer!.stop();
      }
      _logger.d('🎵 System ringtone stopped');
    } catch (e) {
      _logger.e('❌ Failed to stop system ringtone: $e');
    }
  }

  /// Stop system caller tone
  Future<void> _stopSystemCallerTone() async {
    try {
      if (_callerTonePlayer?.playing == true) {
        await _callerTonePlayer!.stop();
      }
      _logger.d('🎵 System caller tone stopped');
    } catch (e) {
      _logger.e('❌ Failed to stop system caller tone: $e');
    }
  }

  /// Play phone ringtone (simplified using just_audio)
  Future<void> _playPhoneRingtoneViaPlatform({bool isVideoCall = false}) async {
    try {
      // Use the caller tone player for consistency
      await _callerTonePlayer!.setAsset(
        'assets/audio/phone-ringtone-emitting-from-ear-piece.mp3',
      );
      await _callerTonePlayer!.setLoopMode(LoopMode.all);
      await _callerTonePlayer!.setVolume(isVideoCall ? 0.8 : 0.9);
      await _callerTonePlayer!.play();
      _logger.d('🎵 Phone ringtone started via just_audio');
    } catch (e) {
      _logger.e('❌ Failed to play phone ringtone: $e');
      rethrow;
    }
  }

  /// Stop phone ringtone (simplified using just_audio)
  Future<void> _stopPhoneRingtoneViaPlatform() async {
    try {
      if (_callerTonePlayer?.playing == true) {
        await _callerTonePlayer!.stop();
      }
      _logger.d('🎵 Phone ringtone stopped');
    } catch (e) {
      _logger.e('❌ Failed to stop phone ringtone: $e');
    }
  }

  /// Stop custom call ringtone (simplified using just_audio)
  Future<void> _stopCustomCallRingtone() async {
    try {
      if (_ringtonePlayer?.playing == true) {
        await _ringtonePlayer!.stop();
      }
      _logger.d('🎵 Custom call ringtone stopped');
    } catch (e) {
      _logger.e('❌ Failed to stop custom call ringtone: $e');
    }
  }

  /// Pause current audio
  void _pauseCurrentAudio() {
    try {
      _ringtonePlayer?.pause();
      _callerTonePlayer?.pause();
      _logger.d('🎵 Audio paused');
    } catch (e) {
      _logger.e('❌ Failed to pause audio: $e');
    }
  }

  /// Resume current audio
  void _resumeCurrentAudio() {
    try {
      if (_currentMode == AudioMode.ringtone &&
          _ringtonePlayer?.playerState.playing == false) {
        _ringtonePlayer?.play();
      } else if (_currentMode == AudioMode.calling &&
          _callerTonePlayer?.playerState.playing == false) {
        _callerTonePlayer?.play();
      }
      _logger.d('🎵 Audio resumed');
    } catch (e) {
      _logger.e('❌ Failed to resume audio: $e');
    }
  }

  /// Stop all audio playbook - Enhanced with immediate stopping
  Future<void> _stopAllAudio() async {
    try {
      _logger.d('🎵 Stopping all audio players...');

      // Force stop ringtone player
      if (_ringtonePlayer != null) {
        try {
          if (_ringtonePlayer!.playing) {
            await _ringtonePlayer!.stop();
            await _ringtonePlayer!.seek(Duration.zero);
          }
        } catch (e) {
          _logger.w('⚠️ Error stopping ringtone player: $e');
        }
      }

      // Force stop caller tone player
      if (_callerTonePlayer != null) {
        try {
          if (_callerTonePlayer!.playing) {
            await _callerTonePlayer!.stop();
            await _callerTonePlayer!.seek(Duration.zero);
          }
        } catch (e) {
          _logger.w('⚠️ Error stopping caller tone player: $e');
        }
      }

      // Stop system ringtone and custom ringtone
      await _stopSystemRingtone();
      await _stopCustomCallRingtone();

      _logger.d('🎵 All audio stopped');
    } catch (e) {
      _logger.e('❌ Failed to stop all audio: $e');
    }
  }

  /// Stop ringtone - Enhanced with immediate stopping
  Future<void> stopRingtone() async {
    try {
      _logger.i('🎵 Stopping ringtone...');

      // Stop system ringtone via platform channel
      try {
        await platform.invokeMethod('stopSystemRingtone');
        _logger.d('🎵 System ringtone stopped via platform');
      } catch (e) {
        _logger.w('⚠️ Error stopping system ringtone via platform: $e');
      }

      // Stop custom ringtone via platform channel
      try {
        await platform.invokeMethod('stopCustomCallRingtone');
        _logger.d('🎵 Custom ringtone stopped via platform');
      } catch (e) {
        _logger.w('⚠️ Error stopping custom ringtone via platform: $e');
      }

      // Force stop ringtone player as backup
      if (_ringtonePlayer != null) {
        try {
          if (_ringtonePlayer!.playing) {
            await _ringtonePlayer!.stop();
            await _ringtonePlayer!.seek(Duration.zero);
          }
          // Set loop mode to none to prevent restart
          await _ringtonePlayer!.setLoopMode(LoopMode.off);
        } catch (e) {
          _logger.w('⚠️ Error stopping ringtone player: $e');
        }
      }

      // Cancel timeout and reset mode
      _cancelCallTimeout();
      _currentMode = AudioMode.normal;

      // Release audio focus immediately
      await _releaseAudioFocus();

      // Restore normal audio routing (WebRTC handles this automatically)
      try {
        await Helper.setSpeakerphoneOn(false);
      } catch (e) {
        _logger.w('⚠️ Error restoring normal audio: $e');
      }

      _logger.i('✅ Ringtone stopped');
    } catch (e) {
      _logger.e('❌ Failed to stop ringtone: $e');
    }
  }

  /// Handle call acceptance - stops ringtone and configures for call
  Future<void> onCallAccepted({bool useSpeaker = false}) async {
    try {
      _logger.i(
        '📞 Call accepted - stopping ringtone and configuring for call...',
      );

      // Stop ringtone immediately
      await stopRingtone();

      // Configure audio for call
      await configureAudioForCall(useSpeaker: useSpeaker);

      _logger.i('✅ Call acceptance handled successfully');
    } catch (e) {
      _logger.e('❌ Failed to handle call acceptance: $e');
    }
  }

  /// Handle call rejection - stops ringtone and restores normal audio
  Future<void> onCallRejected() async {
    try {
      _logger.i(
        '📞 Call rejected - stopping ringtone and restoring normal audio...',
      );

      // Stop ringtone immediately
      await stopRingtone();

      // Ensure normal audio is restored
      await cleanup();

      _logger.i('✅ Call rejection handled successfully');
    } catch (e) {
      _logger.e('❌ Failed to handle call rejection: $e');
    }
  }

  /// SENIOR DEV: Release WebRTC audio session temporarily for ringtones
  Future<void> _releaseWebRTCAudioSession() async {
    try {
      _logger.i('🔧 Temporarily releasing WebRTC audio session for ringtone...');
      
      // Use platform channel to temporarily release WebRTC audio control
      await platform.invokeMethod('releaseAudioSession');
      
      // Small delay to ensure release takes effect
      await Future.delayed(Duration(milliseconds: 100));
      
      _logger.i('✅ WebRTC audio session temporarily released');
    } catch (e) {
      _logger.w('⚠️ Could not release WebRTC audio session: $e (continuing anyway)');
    }
  }

  /// SENIOR DEV: Reclaim WebRTC audio session after ringtone
  Future<void> _reclaimWebRTCAudioSession() async {
    try {
      _logger.i('🔧 Reclaiming WebRTC audio session after ringtone...');
      
      // Use platform channel to reclaim WebRTC audio control
      await platform.invokeMethod('reclaimAudioSession');
      
      _logger.i('✅ WebRTC audio session reclaimed');
    } catch (e) {
      _logger.w('⚠️ Could not reclaim WebRTC audio session: $e (continuing anyway)');
    }
  }

  /// SENIOR DEV FALLBACK: Platform-native ringtone when just_audio fails
  Future<void> _tryPlatformNativeRingtone({required bool isVideoCall}) async {
    try {
      _logger.i('🔧 Attempting platform-native ringtone fallback...');
      
      // Platform-specific ringtone that works with WebRTC
      final result = await platform.invokeMethod('playNativeRingtone', {
        'assetPath': 'assets/audio/phone-ringtone-emitting-from-ear-piece.mp3',
        'isVideoCall': isVideoCall,
        'looping': true,
        'volume': isVideoCall ? 0.8 : 0.9,
      });
      
      if (result == true) {
        _logger.i('✅ Platform-native ringtone started successfully');
        _startCallTimeout(); // Start timeout for native ringtone too
      } else {
        _logger.e('❌ Platform-native ringtone also failed');
      }
    } catch (e) {
      _logger.e('❌ Platform-native ringtone failed: $e');
    }
  }

  /// Stop caller tone - Enhanced with immediate stopping
  Future<void> stopCallerTone() async {
    try {
      _logger.i('🎵 Stopping caller tone...');

      // SENIOR DEV FIX: Stop both just_audio and platform-native audio
      
      // Stop platform-native ringtone first
      try {
        await platform.invokeMethod('stopNativeRingtone');
        _logger.i('✅ Platform-native ringtone stopped');
      } catch (e) {
        _logger.d('ℹ️ Platform-native ringtone stop: $e (normal if not running)');
      }

      // Force stop caller tone player immediately
      if (_callerTonePlayer != null) {
        try {
          if (_callerTonePlayer!.playing) {
            await _callerTonePlayer!.stop();
            await _callerTonePlayer!.seek(Duration.zero);
          }
          // Set loop mode to none to prevent restart
          await _callerTonePlayer!.setLoopMode(LoopMode.off);
        } catch (e) {
          _logger.w('⚠️ Error stopping caller tone player: $e');
        }
      }

      // SENIOR DEV FIX: Reclaim WebRTC audio session when stopping ringtone
      await _reclaimWebRTCAudioSession();

      // CRITICAL: Also stop system caller tone and platform phone ringtone if they were used as fallback
      await _stopSystemCallerTone();
      await _stopPhoneRingtoneViaPlatform();

      // CRITICAL: Force native audio restoration immediately
      try {
        _logger.i('📱 Forcing native audio restoration after caller tone...');
        await platform.invokeMethod('restoreNormalAudio');
        _logger.i('✅ Native audio restored after caller tone');
      } catch (e) {
        _logger.e('❌ Native audio restoration failed after caller tone: $e');
      }

      // Cancel timeout and reset mode
      _cancelCallTimeout();
      _currentMode = AudioMode.normal;

      // Release audio focus immediately
      await _releaseAudioFocus();

      // Restore normal audio routing with delay after native cleanup
      try {
        await Future.delayed(Duration(milliseconds: 100));
        await Helper.setSpeakerphoneOn(false);
      } catch (e) {
        _logger.w('⚠️ Error restoring normal audio: $e');
      }

      _logger.i('✅ Caller tone stopped');
    } catch (e) {
      _logger.e('❌ Failed to stop caller tone: $e');
    }
  }

  /// 🚀 FINAL SOLUTION: WebRTC-Native Speaker Toggle
  Future<void> toggleSpeaker(bool enabled) async {
    try {
      _logger.i('🚀 FINAL: WebRTC-native speaker toggle ($enabled)');

      // 🎯 KEY: Use WebRTC-native speaker control
      try {
        await platform.invokeMethod('setSpeakerphone', {'enabled': enabled});
        _logger.i(
          '🎯 WebRTC-native speaker toggle: ${enabled ? "SPEAKER" : "EARPIECE"}',
        );
      } catch (e) {
        _logger.w('⚠️ WebRTC-native speaker toggle failed: $e');

        // Fallback to flutter_webrtc Helper
        try {
          await Helper.setSpeakerphoneOn(enabled);
          _logger.d('🔄 Fallback to flutter_webrtc Helper successful');
        } catch (fallbackError) {
          _logger.e(
            '❌ Fallback to flutter_webrtc Helper also failed: $fallbackError',
          );
          rethrow;
        }
      }

      _logger.i(
        '✅ FINAL: WebRTC-native speaker toggle completed - ${enabled ? "SPEAKER" : "EARPIECE"}',
      );
    } catch (e) {
      _logger.e('❌ FINAL: WebRTC-native speaker toggle failed: $e');
      rethrow;
    }
  }

  /// CRITICAL FIX: Force reset audio session for subsequent calls
  Future<void> forceResetAudioSessionForNextCall() async {
    try {
      _logger.i(
        '🔄 CallAudioManager: Force resetting audio session for next call',
      );

      // CRITICAL: Ensure all audio stops BEFORE reset
      await _forceStopAllAudio();

      // Add delay to ensure cleanup is complete
      await Future.delayed(Duration(milliseconds: 300));

      // Call iOS native force reset method (which now has proper timing)
      await platform.invokeMethod('forceResetAudioSessionForNextCall');

      // Reset our internal state completely
      _currentMode = AudioMode.normal;

      _logger.i('✅ CallAudioManager: Audio session force reset completed');
    } catch (e) {
      _logger.e('❌ CallAudioManager: Audio session force reset failed: $e');
      rethrow;
    }
  }

  Future<void> _performSpeakerRecovery(bool expectedSpeaker) async {
    try {
      _logger.i(
        '🔧 RESEARCH-BASED RECOVERY: Multi-approach speaker fix for ${expectedSpeaker ? "SPEAKER" : "EARPIECE"}',
      );

      // Approach 1: Try flutter_webrtc Helper
      try {
        await Helper.setSpeakerphoneOn(expectedSpeaker);
        _logger.i('🔧 RECOVERY: flutter_webrtc Helper method applied');

        // Verify after 200ms
        await Future.delayed(Duration(milliseconds: 200));
        final verifyResult = await platform.invokeMethod('setSpeakerphone', {
          'enabled': expectedSpeaker,
        });

        if (verifyResult is Map) {
          final actualSpeaker = verifyResult['actualSpeaker'] as bool?;
          if (actualSpeaker == expectedSpeaker) {
            _logger.i(
              '✅ RECOVERY SUCCESS: Speaker routing corrected via Helper',
            );
            return;
          }
        }
      } catch (e) {
        _logger.w('⚠️ RECOVERY: flutter_webrtc Helper failed: $e');
      }

      // Approach 2: Direct platform retry
      try {
        await Future.delayed(Duration(milliseconds: 100));
        await platform.invokeMethod('setSpeakerphone', {
          'enabled': expectedSpeaker,
        });
        _logger.i('🔧 RECOVERY: Direct platform retry completed');
      } catch (e) {
        _logger.w('⚠️ RECOVERY: Direct platform retry failed: $e');
      }

      _logger.w(
        '🚨 RECOVERY: All approaches attempted, speaker routing may still be incorrect',
      );
    } catch (e) {
      _logger.e('❌ RECOVERY: Speaker recovery failed completely: $e');
    }
  }

  /// 🚀 FINAL SOLUTION: WebRTC-Native Audio Cleanup
  Future<void> cleanup() async {
    try {
      _logger.i('🚀 FINAL: WebRTC-native audio cleanup...');

      // Phase 1: Cancel timeouts and stop notifications
      _cancelCallTimeout();
      await CallNotificationManager.instance.stopIncomingCallNotification();

      // Phase 2: Force stop all audio players
      await _forceStopAllAudio();

      // Phase 3: WebRTC-native audio restoration
      try {
        _logger.i('📱 FINAL: WebRTC-native audio restoration...');
        await platform.invokeMethod('restoreNormalAudio');
        _logger.i('✅ WebRTC-native audio restoration completed');

        // FIXED: Single reset call with proper timing
        await Future.delayed(Duration(milliseconds: 300));
        await platform.invokeMethod('forceResetAudioSessionForNextCall');
        _logger.i('🔄 FINAL: Audio session reset for next call completed');
      } catch (e) {
        _logger.e('❌ WebRTC-native audio restoration failed: $e');
      }

      // Phase 4: Flutter WebRTC cleanup (as backup)
      try {
        await Helper.setSpeakerphoneOn(false);
        _logger.d('📞 Flutter WebRTC cleanup completed');
      } catch (e) {
        _logger.w('⚠️ Flutter WebRTC cleanup failed: $e');
      }

      // Phase 5: Reset state
      await _releaseAudioFocus();
      _currentMode = AudioMode.normal;

      _logger.i('✅ FINAL: WebRTC-native audio cleanup completed');
    } catch (e) {
      _logger.e('❌ FINAL: WebRTC-native audio cleanup failed: $e');

      // Emergency cleanup
      try {
        await Helper.setSpeakerphoneOn(false);
        await platform.invokeMethod('restoreNormalAudio');
        _logger.w('🚨 Emergency audio cleanup completed');
      } catch (fallbackError) {
        _logger.e('❌ Emergency audio cleanup failed: $fallbackError');
      }
    }
  }

  /// Force stop all audio - More aggressive stopping
  Future<void> _forceStopAllAudio() async {
    try {
      _logger.d('🎵 Force stopping all audio players...');

      // Force stop and reset ringtone player
      if (_ringtonePlayer != null) {
        try {
          await _ringtonePlayer!.stop();
          await _ringtonePlayer!.seek(Duration.zero);
          await _ringtonePlayer!.setLoopMode(LoopMode.off);
        } catch (e) {
          _logger.w('⚠️ Force stop ringtone error: $e');
        }
      }

      // Force stop and reset caller tone player
      if (_callerTonePlayer != null) {
        try {
          await _callerTonePlayer!.stop();
          await _callerTonePlayer!.seek(Duration.zero);
          await _callerTonePlayer!.setLoopMode(LoopMode.off);
        } catch (e) {
          _logger.w('⚠️ Force stop caller tone error: $e');
        }
      }

      // Stop system ringtone, custom ringtone, system caller tone, and platform phone ringtone
      await _stopSystemRingtone();
      await _stopSystemCallerTone();
      await _stopCustomCallRingtone();
      await _stopPhoneRingtoneViaPlatform();

      // Small delay to ensure stops are processed
      await Future.delayed(Duration(milliseconds: 100));

      _logger.d('🎵 Force stop completed');
    } catch (e) {
      _logger.e('❌ Force stop failed: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      await cleanup();

      await _ringtonePlayer?.dispose();
      await _callerTonePlayer?.dispose();

      _ringtonePlayer = null;
      _callerTonePlayer = null;
      _isInitialized = false;

      _logger.i('✅ CallAudioManager: Disposed');
    } catch (e) {
      _logger.e('❌ CallAudioManager: Dispose failed: $e');
    }
  }

  /// Emergency stop - Immediately halt all audio without waiting
  /// Emergency stop audio WITHOUT killing WebRTC session (for call accept)
  Future<void> emergencyStopAudio() async {
    try {
      _logger.w('🚨 FIXED: Emergency audio stop for CALL ACCEPT (WebRTC-safe)');

      // Cancel timeout immediately
      _timeoutTimer?.cancel();
      _timeoutTimer = null;

      // Force stop players without waiting for completion
      _ringtonePlayer?.stop().catchError(
        (e) => _logger.w('Emergency ringtone stop error: $e'),
      );
      _callerTonePlayer?.stop().catchError(
        (e) => _logger.w('Emergency caller tone stop error: $e'),
      );

      // Reset loop modes
      _ringtonePlayer?.setLoopMode(LoopMode.off).catchError((e) => null);
      _callerTonePlayer?.setLoopMode(LoopMode.off).catchError((e) => null);

      // Force stop all audio via just_audio (more reliable than platform calls)
      try {
        await _stopAllAudio();
      } catch (e) {
        _logger.w('Emergency stop all audio error: $e');
      }

      // FIXED: DO NOT call restoreNormalAudio during call accept - it kills WebRTC!
      // Instead, only stop ringtones and prepare for WebRTC initialization
      try {
        _logger.w(
          '📱 FIXED: WebRTC-safe ringtone cleanup (no session kill)...',
        );
        await platform.invokeMethod('stopSystemRingtone');
        await platform.invokeMethod('stopCustomCallRingtone');
        _logger.w('✅ FIXED: Ringtones stopped without killing WebRTC session');
      } catch (e) {
        _logger.e('❌ Ringtone stop failed: $e');
      }

      // FIXED: Only reset speaker routing, don't kill WebRTC audio session
      try {
        await Helper.setSpeakerphoneOn(false);
        await Future.delayed(Duration(milliseconds: 100));
        // Second attempt
        await Helper.setSpeakerphoneOn(false);
      } catch (e) {
        _logger.w('Emergency speaker restore error: $e');
      }

      // FIXED: Don't reset audio mode - let WebRTC manage it
      // _currentMode = AudioMode.normal; // REMOVED - WebRTC will set proper mode

      _logger.w(
        '🚨 FIXED: Emergency audio stop completed (WebRTC session preserved)',
      );
    } catch (e) {
      _logger.e('❌ Emergency stop failed: $e');
    }
  }

  /// Full audio restoration for call END (this kills WebRTC session)
  Future<void> emergencyStopAudioAndRestore() async {
    try {
      _logger.w('🚨 Emergency audio stop AND restore (for call end)...');

      // Cancel timeout immediately
      _timeoutTimer?.cancel();
      _timeoutTimer = null;

      // Force stop players without waiting for completion
      _ringtonePlayer?.stop().catchError(
        (e) => _logger.w('Emergency ringtone stop error: $e'),
      );
      _callerTonePlayer?.stop().catchError(
        (e) => _logger.w('Emergency caller tone stop error: $e'),
      );

      // Reset loop modes
      _ringtonePlayer?.setLoopMode(LoopMode.off).catchError((e) => null);
      _callerTonePlayer?.setLoopMode(LoopMode.off).catchError((e) => null);

      // Force stop all audio via just_audio (more reliable than platform calls)
      try {
        await _stopAllAudio();
      } catch (e) {
        _logger.w('Emergency stop all audio error: $e');
      }

      // CRITICAL: Full native audio restoration (kills WebRTC - only for call end)
      try {
        _logger.w('📱 Emergency native audio restoration...');
        await platform.invokeMethod('restoreNormalAudio');
        await Future.delayed(Duration(milliseconds: 150));
        // Second attempt for stubborn cases
        await platform.invokeMethod('restoreNormalAudio');
        _logger.w('✅ Emergency native audio restoration completed');
      } catch (e) {
        _logger.e('❌ Emergency native audio restoration failed: $e');
      }

      // Restore normal audio routing with multiple attempts
      try {
        await Helper.setSpeakerphoneOn(false);
        await Future.delayed(Duration(milliseconds: 100));
        // Second attempt
        await Helper.setSpeakerphoneOn(false);
      } catch (e) {
        _logger.w('Emergency speaker restore error: $e');
      }

      // Reset state
      _currentMode = AudioMode.normal;

      _logger.w('🚨 Emergency audio stop and restore completed');
    } catch (e) {
      _logger.e('❌ Emergency stop failed: $e');
    }
  }

  // Getters
  bool get isInitialized => _isInitialized;
  AudioMode get currentMode => _currentMode;
  bool get hasActiveTimeout => _timeoutTimer?.isActive ?? false;
}
