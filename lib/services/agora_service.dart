import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

typedef Future<String> TokenRefreshCallback(String channelName, int uid);

/// Service to handle Agora RTC logic
class AgoraService {
  static RtcEngine? _engine;
  
  /// Initialize Agora Engine
  static Future<RtcEngine> initEngine(String appId, {TokenRefreshCallback? tokenRefreshCallback}) async {
    if (_engine != null) return _engine!;

    // Request permissions
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    if (tokenRefreshCallback != null) {
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onTokenPrivilegeWillExpire: (connection, token) async {
            print('Token privilege will expire. Renewing token...');
            final newToken = await tokenRefreshCallback(connection.channelId!, connection.localUid!);
            await _engine!.renewToken(newToken);
            print('Token renewed successfully.');
          },
        ),
      );
    }

    return _engine!;
  }

  /// Join a channel as a Broadcaster
  static Future<void> joinChannelAsBroadcaster({
    required String token,
    required String channelName,
    required int uid,
  }) async {
    if (_engine == null) throw Exception('Agora engine not initialized');

    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine!.enableVideo();
    await _engine!.startPreview();

    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(),
    );
  }

  /// Join a channel as a Audience (Viewer)
  static Future<void> joinChannelAsAudience({
    required String token,
    required String channelName,
    required int uid,
  }) async {
    if (_engine == null) throw Exception('Agora engine not initialized');

    await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
    await _engine!.enableVideo();

    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(),
    );
  }

  /// Leave channel and dispose engine
  static Future<void> leaveAndDispose() async {
    if (_engine == null) return;

    await _engine!.leaveChannel();
    await _engine!.release();
    _engine = null;
  }
}
