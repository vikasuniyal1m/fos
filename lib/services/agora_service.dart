import 'dart:convert';
import 'dart:typed_data';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

/// Agora RTC: keys stay on PHP; this service only uses token + app_id from backend.
class AgoraService {
  static RtcEngine? _engine;
  static int? _commentStreamId;

  /// Initialize with appId from PHP token response (required for SDK).
  static Future<RtcEngine> initEngineWithAppId(String appId) async {
    // Always reinitialize to ensure clean state for rejoining
    if (_engine != null) {
      await _engine!.leaveChannel();
      await _engine!.release();
      _engine = null;
    }

    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    // Set video parameters for smoother streaming
    await _engine!.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 720, height: 1280),
        frameRate: 30,
        bitrate: 2000,
        orientationMode: OrientationMode.orientationModeAdaptive,
      ),
    );

    return _engine!;
  }

  /// Join as broadcaster (host). Token and appId from PHP.
  static Future<void> joinChannelAsBroadcaster({
    required String token,
    required String channelId,
    required String userAccount,
    required String appId,
  }) async {
    if (_engine == null) {
      await initEngineWithAppId(appId);
    }
    if (_engine == null) throw Exception('Agora engine not initialized');

    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine!.enableVideo();
    await _engine!.startPreview();

    await _engine!.joinChannelWithUserAccount(
      token: token,
      channelId: channelId,
      userAccount: userAccount,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );
    await _createCommentStream();
  }

  /// Join as audience (viewer). Token and appId from PHP.
  static Future<void> joinChannelAsAudience({
    required String token,
    required String channelId,
    required String userAccount,
    required String appId,
  }) async {
    if (_engine == null) {
      await initEngineWithAppId(appId);
    }
    if (_engine == null) throw Exception('Agora engine not initialized');

    await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
    await _engine!.enableVideo();

    await _engine!.joinChannelWithUserAccount(
      token: token,
      channelId: channelId,
      userAccount: userAccount,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: ClientRoleType.clientRoleAudience,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );
    await _createCommentStream();
  }

  static Future<void> _createCommentStream() async {
    if (_engine == null) return;
    try {
      final id = await _engine!.createDataStream(
        const DataStreamConfig(ordered: false, syncWithAudio: false),
      );
      _commentStreamId = id;
    } catch (_) {
      _commentStreamId = null;
    }
  }

  static RtcEngine? get engine => _engine;
  static int? get commentStreamId => _commentStreamId;

  /// Send a live comment so all participants (host + viewers) see it.
  static Future<bool> sendComment(String payload) async {
    if (_engine == null || _commentStreamId == null) return false;
    try {
      final data = Uint8List.fromList(utf8.encode(payload));
      await _engine!.sendStreamMessage(
        streamId: _commentStreamId!,
        data: data,
        length: data.length,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Flip camera (front/back). Broadcaster only.
  static Future<void> switchCamera() async {
    if (_engine == null) return;
    await _engine!.switchCamera();
  }

  /// Mute/unmute local microphone. Broadcaster only.
  static Future<void> muteLocalAudio(bool mute) async {
    if (_engine == null) return;
    await _engine!.muteLocalAudioStream(mute);
  }

  /// Turn camera off/on. Broadcaster only. Uses enableLocalVideo so camera
  /// actually stops (muteLocalVideoStream only stops publishing, camera keeps running).
  static Future<void> muteLocalVideo(bool mute) async {
    if (_engine == null) return;
    await _engine!.enableLocalVideo(!mute);
    if (!mute) await _engine!.startPreview();
  }

  static Future<void> leaveAndDispose() async {
    if (_engine == null) return;
    await _engine!.leaveChannel();
    await _engine!.release();
    _engine = null;
    _commentStreamId = null;
  }
}
