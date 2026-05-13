import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fruitsofspirit/config/api_config.dart';
import 'package:fruitsofspirit/services/agora_service.dart';
import 'package:fruitsofspirit/services/cache_service.dart';
import 'package:fruitsofspirit/services/emojis_service.dart';
import 'package:fruitsofspirit/services/fruit_service.dart';
import 'package:fruitsofspirit/services/hive_cache_service.dart';
import 'package:fruitsofspirit/services/live_streaming_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';

/// One live comment or emoji reaction (in-memory for smooth UI; can plug backend later).
class _LiveComment {
  final String id;
  final String userName;
  final String text;
  final bool isEmoji;
  final DateTime time;

  _LiveComment({required this.id, required this.userName, required this.text, this.isEmoji = false, DateTime? time}) : time = time ?? DateTime.now();
}

/// Agora live: token + app_id from PHP; join as host or viewer. YouTube/Instagram-style UI.
class AgoraLiveScreen extends StatefulWidget {
  final String channelName;
  final String title;
  final bool isBroadcaster;

  const AgoraLiveScreen({
    Key? key,
    required this.channelName,
    this.title = 'Live',
    this.isBroadcaster = false,
  }) : super(key: key);

  @override
  State<AgoraLiveScreen> createState() => _AgoraLiveScreenState();
}

class _AgoraLiveScreenState extends State<AgoraLiveScreen> {
  bool _isLoading = true;
  String? _error;
  bool _localUserJoined = false;
  int? _remoteUid;
  /// Viewer: true when host ended the live (so we show "Live video ended")
  bool _hostEndedLive = false;

  // Viewer count tracking
  final Set<int> _remoteUids = {};
  int get _viewerCount => _remoteUids.length;

  // Broadcaster controls
  bool _micMuted = false;
  bool _videoMuted = false;
  bool _hostVideoMuted = false;

  // Comments & reactions (smooth, in-memory; backend can be added later)
  final List<_LiveComment> _comments = [];
  final ScrollController _commentScrollController = ScrollController();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _showCommentInput = false;

  // Floating emoji reactions (Instagram-style)
  final List<Map<String, dynamic>> _floatingEmojis = [];
  int _floatingEmojiId = 0;
  /// Quick reaction row: fruit emojis from API (Fruit screen jaisa); image_url when emoji_char empty
  List<Map<String, dynamic>> _quickFruitEmojis = [];

  String _viewerName = 'You';
  String? _profilePhotoUrl;
  bool _showFollowerBanner = true;
  String? _myUserId;

  Timer? _commentPollTimer;
  final Set<String> _seenCommentIds = {};

  @override
  void initState() {
    super.initState();
    _loadViewerName();
    _loadQuickFruitEmojis();
    _joinChannel();
    _startCommentPolling();
  }

  /// Saare variants chahiye (har fruit ke 3) — fruit_screen_all_variants use karo, nahi to API se full list
  Future<void> _loadQuickFruitEmojis() async {
    try {
      var cached = HiveCacheService.getCachedList('fruit_screen_all_variants');
      if (cached.isEmpty) cached = await CacheService.getCachedList('fruit_screen_all_variants');
      if (mounted && cached.isNotEmpty) {
        setState(() => _quickFruitEmojis = List<Map<String, dynamic>>.from(cached));
        return;
      }
      final fruitFromTable = await FruitService.getAllFruit();
      if (fruitFromTable.isEmpty && mounted) return;
      var emojis = await EmojisService.getEmojis(status: 'Active', sortBy: 'image_url', order: 'ASC');
      if (emojis.isEmpty && mounted) return;
      final fruitNames = fruitFromTable.map((f) => (f['name'] as String? ?? '').toLowerCase().trim()).toList();
      emojis = emojis.where((emoji) {
        final name = (emoji['name'] as String? ?? '').toLowerCase();
        final category = (emoji['category'] as String? ?? '').toLowerCase();
        final matchesTable = fruitNames.any((fn) {
          final ew = name.split(RegExp(r'[\s_\-]+')).where((w) => w.isNotEmpty).map((w) => w.toLowerCase()).toList();
          final fw = fn.split(RegExp(r'[\s_\-]+')).where((w) => w.isNotEmpty).map((w) => w.toLowerCase()).toList();
          return fw.any((fw0) => ew.any((ew0) => ew0.contains(fw0) || fw0.contains(ew0) || ew0 == fw0)) || name.contains(fn) || fn.contains(name);
        });
        final hasFruitCat = category.isNotEmpty && (category.contains('fruit') || category.contains('spirit')) && !category.contains('opposite');
        final generic = RegExp(r'^emoji \d+$').hasMatch(name.trim());
        return (matchesTable || hasFruitCat) && !generic;
      }).toList();
      final list = List<Map<String, dynamic>>.from(emojis);
      if (list.isNotEmpty) {
        await HiveCacheService.cacheList('fruit_screen_all_variants', list);
        await CacheService.cacheList('fruit_screen_all_variants', list);
      }
      if (mounted && list.isNotEmpty) setState(() => _quickFruitEmojis = list);
    } catch (_) {
      if (mounted) setState(() => _quickFruitEmojis = []);
    }
  }

  Future<void> _loadViewerName() async {
    final user = await UserStorage.getUser();
    final name = user?['name'] ?? user?['username'] ?? user?['full_name'];
    final s = name?.toString().trim();
    final photo = user?['profile_photo'] ?? user?['image'] ?? user?['avatar'] ?? user?['profile_picture'];
    var photoUrl = photo?.toString().trim();
    if (photoUrl != null && photoUrl.isNotEmpty && !photoUrl.startsWith('http')) {
      final base = ApiConfig.baseUrl.replaceFirst(RegExp(r'/api$'), '');
      photoUrl = base + (photoUrl.startsWith('/') ? photoUrl : '/$photoUrl');
    }
    if (mounted) {
      setState(() {
        if (s != null && s.isNotEmpty) _viewerName = s;
        if (photoUrl != null && photoUrl.isNotEmpty) _profilePhotoUrl = photoUrl;
      });
    }
  }

  Future<void> _joinChannel() async {
    try {
      final userId = await UserStorage.getUserId();
      if (userId == null) {
        setState(() {
          _error = 'Please login first.';
          _isLoading = false;
        });
        return;
      }
      _myUserId = userId.toString();

      if (widget.isBroadcaster) {
        final cameraStatus = await Permission.camera.request();
        final micStatus = await Permission.microphone.request();
        if (!cameraStatus.isGranted || !micStatus.isGranted) {
          if (mounted) {
            setState(() {
              _error = 'Camera and microphone are required to go live. Please allow in Settings.';
              _isLoading = false;
            });
          }
          return;
        }
      }

      final role = widget.isBroadcaster ? 1 : 2;
      final cred = await LiveStreamingService.getAgoraToken(
        channelName: widget.channelName,
        role: role,
      );

      final token = cred['token'] as String? ?? '';
      final appId = cred['app_id'] as String?;
      final channelName = cred['channel_name'] as String? ?? widget.channelName;

      if (appId == null || appId.isEmpty) {
        setState(() {
          _error = 'Could not get Agora app_id from server.';
          _isLoading = false;
        });
        return;
      }
      // Empty token is allowed when Agora project is "App ID only" (testing mode)

      final engine = await AgoraService.initEngineWithAppId(appId);

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            if (mounted) {
              setState(() {
                _localUserJoined = true;
                _isLoading = false;
              });
              if (widget.isBroadcaster) {
                LiveStreamingService.startAgoraLive(
                  channelName: widget.channelName,
                  title: widget.title,
                );
              }
              _fetchCommentsOnce();
            }
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            if (mounted) {
              setState(() {
                _remoteUid = remoteUid;
                _remoteUids.add(remoteUid);
              });
            }
          },
          onUserOffline: (RtcConnection connection, int remoteUid,
              UserOfflineReasonType reason) {
            if (mounted) {
              setState(() {
                _remoteUids.remove(remoteUid);
                if (_remoteUids.isEmpty) {
                  _remoteUid = null;
                  if (!widget.isBroadcaster) _hostEndedLive = true;
                } else {
                  // Still have other viewers, update remoteUid to first available
                  _remoteUid = _remoteUids.first;
                }
              });
            }
          },
          onUserMuteVideo: (RtcConnection connection, int remoteUid, bool muted) {
            if (mounted) {
              setState(() {
                if (_remoteUid == remoteUid) {
                  _hostVideoMuted = muted;
                }
              });
            }
          },
          onError: (ErrorCodeType err, String msg) {
            if (mounted) {
              final text = msg.trim().isEmpty
                  ? 'Agora error: $err'
                  : msg;
              setState(() {
                _error = text;
                _isLoading = false;
              });
            }
          },
          onStreamMessage: (RtcConnection connection, int remoteUid, int streamId, Uint8List data, int length, int ts) {
            if (!mounted) return;
            try {
              final len = length > data.length ? data.length : length;
              if (len <= 0) return;
              final json = utf8.decode(data.sublist(0, len));
              final map = jsonDecode(json) as Map<String, dynamic>?;
              if (map == null) return;
              if (map['type'] == 'reaction') {
                if (_myUserId != null && map['u'] == _myUserId) return;
                final emojiData = <String, dynamic>{
                  'image_url': map['image_url'],
                  'emoji_char': map['emoji_char'] ?? '',
                  'name': map['name'],
                };
                final id = ++_floatingEmojiId;
                setState(() => _floatingEmojis.add({'id': id, 'data': emojiData}));
                Future.delayed(const Duration(milliseconds: 2100), () {
                  if (mounted) setState(() => _floatingEmojis.removeWhere((e) => e['id'] == id));
                });
                return;
              }
              final userName = map['n'] as String? ?? 'Someone';
              final text = map['t'] as String? ?? '';
              final isEmoji = map['e'] as bool? ?? false;
              if (text.isEmpty) return;
              setState(() {
                _comments.add(_LiveComment(
                  id: '${remoteUid}_${DateTime.now().millisecondsSinceEpoch}',
                  userName: userName,
                  text: text,
                  isEmoji: isEmoji,
                ));
              });
              Future.delayed(const Duration(milliseconds: 100), () {
                if (_commentScrollController.hasClients) {
                  _commentScrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
                }
              });
            } catch (_) {}
          },
        ),
      );

      if (widget.isBroadcaster) {
        await AgoraService.joinChannelAsBroadcaster(
          token: token,
          channelId: channelName,
          userAccount: userId.toString(),
          appId: appId,
        );
      } else {
        await AgoraService.joinChannelAsAudience(
          token: token,
          channelId: channelName,
          userAccount: userId.toString(),
          appId: appId,
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        // Check if stream has ended
        if (errorMsg.contains('ended') || errorMsg.contains('not found')) {
          setState(() {
            _hostEndedLive = true;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = errorMsg;
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _commentPollTimer?.cancel();
    _commentScrollController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    if (widget.isBroadcaster) {
      LiveStreamingService.stopStream(widget.channelName).catchError((_) {});
    }
    AgoraService.leaveAndDispose();
    super.dispose();
  }

  /// Back / close: viewer = confirm leave; host = confirm end live (then stop stream + camera + pop)
  Future<void> _requestExit() async {
    final isHost = widget.isBroadcaster;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.themeColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLG)),
        title: Text(
          isHost ? 'End live video?' : 'Leave live?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        ),
        content: Text(
          isHost
              ? 'Are you sure you want to end the live video? Your camera and stream will stop, and viewers will see that the live has ended.'
              : 'Are you sure you want to leave? You will stop watching this live.',
          style: TextStyle(fontSize: 14, height: 1.4, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: isHost ? AppTheme.errorColor : AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
            ),
            child: Text(isHost ? 'End live' : 'Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (isHost) {
      try {
        await LiveStreamingService.stopStream(widget.channelName);
      } catch (_) {
        // Ignore: no Overlay on this screen for snackbar; host still leaves and pops.
      }
      AgoraService.leaveAndDispose();
    }
    if (mounted) Get.back();
  }

  void _startCommentPolling() {
    _commentPollTimer?.cancel();
    _commentPollTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) => _fetchCommentsOnce());
  }

  Future<void> _fetchCommentsOnce() async {
    if (!mounted) return;
    List<Map<String, dynamic>> list;
    try {
      list = await LiveStreamingService.getLiveComments(widget.channelName);
    } catch (e) {
      return;
    }
    if (!mounted || list.isEmpty) return;
    var didUpdate = false;
    for (final c in list) {
      final id = (c['id'] ?? c['comment_id'] ?? '').toString();
      if (id.isEmpty || _seenCommentIds.contains(id)) continue;
      final userName = c['user_name'] as String? ?? 'Someone';
      final text = c['text'] as String? ?? '';
      final isEmoji = c['is_emoji'] == true || c['is_emoji'] == 1;
      if (userName == _viewerName && _comments.any((x) => x.text == text)) continue;
      _seenCommentIds.add(id);
      setState(() {
        _comments.add(_LiveComment(id: id, userName: userName, text: text, isEmoji: isEmoji));
        didUpdate = true;
      });
      if (isEmoji && text.isNotEmpty) {
        try {
          final data = jsonDecode(text) as Map<String, dynamic>?;
          if (data != null && (data['image_url'] != null || data['emoji_char'] != null)) {
            final emojiData = <String, dynamic>{
              'image_url': data['image_url'],
              'emoji_char': data['emoji_char'] ?? '',
              'name': data['name'],
            };
            final fid = ++_floatingEmojiId;
            setState(() => _floatingEmojis.add({'id': fid, 'data': emojiData}));
            Future.delayed(const Duration(milliseconds: 2100), () {
              if (mounted) setState(() => _floatingEmojis.removeWhere((e) => e['id'] == fid));
            });
          }
        } catch (_) {}
      }
    }
    if (didUpdate && mounted && _commentScrollController.hasClients) {
      _commentScrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  void _addComment(String text, {bool isEmoji = false}) {
    final t = text.trim();
    if (t.isEmpty) return;
    setState(() {
      _comments.add(_LiveComment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userName: _viewerName,
        text: t,
        isEmoji: isEmoji,
      ));
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_commentScrollController.hasClients) {
        _commentScrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
    final payload = jsonEncode(<String, dynamic>{'n': _viewerName, 't': t, 'e': isEmoji});
    AgoraService.sendComment(payload);
    LiveStreamingService.addLiveComment(channelName: widget.channelName, userName: _viewerName, text: t, isEmoji: isEmoji);
  }

  /// Sirf text comments (strip mein emoji nahi dikhate)
  List<_LiveComment> get _textComments => _comments.where((c) => !c.isEmoji).toList();

  /// Known fruit words — name me jo bhi word ye ho, usi se group (Grapes Meekness 3 / Meekness Grapes 1 dono -> grapes)
  static const Set<String> _fruitWords = {
    'strawberry', 'pineapple', 'grapes', 'peach', 'banana', 'lemon', 'watermelon',
    'apple', 'mango', 'orange',
  };

  static String _fruitTypeKey(Map<String, dynamic> e) {
    final name = (e['name'] as String? ?? '').trim();
    final parts = name.split(RegExp(r'[\s_\-]+')).where((w) => w.isNotEmpty).toList();
    for (final p in parts) {
      final lower = p.toLowerCase();
      if (_fruitWords.contains(lower)) return lower;
    }
    if (parts.length >= 3) return parts[1].toLowerCase();
    if (parts.length == 2) return parts[0].toLowerCase();
    if (parts.isNotEmpty) return parts[0].toLowerCase();
    final cat = (e['category'] as String? ?? '').trim();
    return cat.isEmpty ? 'other' : cat.toLowerCase();
  }

  Map<String, List<Map<String, dynamic>>> _groupEmojisByFruitType(List<Map<String, dynamic>> list) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final e in list) {
      final key = _fruitTypeKey(e);
      map.putIfAbsent(key, () => []).add(e);
    }
    for (final key in map.keys.toList()) {
      map[key]!.sort((a, b) => ((a['name'] as String? ?? '').compareTo((b['name'] as String? ?? ''))));
    }
    return map;
  }

  void _onEmojiTap(Map<String, dynamic> emojiData) {
    final id = ++_floatingEmojiId;
    setState(() => _floatingEmojis.add({'id': id, 'data': emojiData}));
    Future.delayed(const Duration(milliseconds: 2100), () {
      if (mounted) setState(() => _floatingEmojis.removeWhere((e) => e['id'] == id));
    });
    final payload = jsonEncode(<String, dynamic>{
      'type': 'reaction',
      'u': _myUserId,
      'n': _viewerName,
      'image_url': emojiData['image_url'],
      'emoji_char': emojiData['emoji_char'] ?? '',
      'name': emojiData['name'],
    });
    AgoraService.sendComment(payload);
    final reactionText = jsonEncode(<String, dynamic>{
      'image_url': emojiData['image_url'],
      'emoji_char': emojiData['emoji_char'] ?? '',
      'name': emojiData['name'],
    });
    LiveStreamingService.addLiveComment(channelName: widget.channelName, userName: _viewerName, text: reactionText, isEmoji: true);
  }

  /// Fruit tap / arrow tap: sirf us fruit ke 3 variants dikhao (simple picker, no Fruit UI)
  void _showVariantOverlay(List<Map<String, dynamic>> variants) {
    if (variants.isEmpty) return;
    final list = List<Map<String, dynamic>>.from(variants);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.themeColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, spreadRadius: 2)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose variant', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: list.map((v) => InkWell(
                  onTap: () {
                    _onEmojiTap(v);
                    Navigator.of(ctx).pop();
                  },
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(child: _buildQuickReactionItem(v)),
                    ),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Joining ${widget.isBroadcaster ? "as host" : "stream"}...',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      final isPermissionError = _error!.toLowerCase().contains('camera') ||
          _error!.toLowerCase().contains('microphone') ||
          _error!.toLowerCase().contains('permission');
      final isInvalidToken = _error!.toLowerCase().contains('invalidtoken') ||
          _error!.toLowerCase().contains('invalid token');
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text('Live'), backgroundColor: Colors.black),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Icon(
                  isPermissionError ? Icons.videocam_off : Icons.error_outline,
                  size: 72,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _error!.isEmpty ? 'Unknown error' : _error!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (isInvalidToken) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Fix: On your server, set Agora App ID and Primary Certificate from the SAME project (console.agora.io) in includes/agora_env.php. No extra spaces.',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 13,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                if (isPermissionError)
                  ElevatedButton.icon(
                    onPressed: () => openAppSettings(),
                    icon: const Icon(Icons.settings),
                    label: const Text('Open Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (isPermissionError) const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Get.back(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final engine = AgoraService.engine;
    if (engine == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text('Live'), backgroundColor: Colors.black),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'Could not start live. Please try again.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Get.back(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.black,
        body: Stack(
          children: [
          // GestureDetector for video and top area - dismisses keyboard on tap
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              behavior: HitTestBehavior.translucent,
              child: Stack(
                children: [
          // Video
          Center(
            child: widget.isBroadcaster
                ? _localUserJoined
                    ? _videoMuted
                        ? Container(color: Colors.black, width: double.infinity, height: double.infinity)
                        : AgoraVideoView(
                            controller: VideoViewController(
                              rtcEngine: engine,
                              canvas: const VideoCanvas(uid: 0),
                            ),
                          )
                    : const CircularProgressIndicator(color: Colors.white)
                : _remoteUid != null
                    ? _hostVideoMuted // Check if host video is muted
                        ? Container(color: Colors.black, width: double.infinity, height: double.infinity) // Show black screen
                        : AgoraVideoView(
                            controller: VideoViewController.remote(
                              rtcEngine: engine,
                              canvas: VideoCanvas(uid: _remoteUid!),
                              connection: RtcConnection(channelId: widget.channelName),
                            ),
                          )
                    : _hostEndedLive
                        ? _buildHostEndedOverlay()
                        : const Text('Waiting for host...', style: TextStyle(color: Colors.white70)),
          ),
          // Floating emoji reactions (Instagram-style)
          ..._floatingEmojis.map((e) => _buildFloatingEmoji(e['data'] as Map<String, dynamic>, e['id'] as int)),
          // Top bar (Instagram-style: profile + name + LIVE + menu + close)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Row(
                children: [
                  // Profile + username + chevron (left)
                  Flexible(
                    child: GestureDetector(
                      onTap: () {},
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white24,
                            backgroundImage: _profilePhotoUrl != null && _profilePhotoUrl!.startsWith('http')
                                ? NetworkImage(_profilePhotoUrl!)
                                : null,
                            child: _profilePhotoUrl == null || !_profilePhotoUrl!.startsWith('http')
                                ? Text(_viewerName.isNotEmpty ? _viewerName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 16))
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _viewerName,
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 22),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // LIVE badge (pink like reference)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE91E8C),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.white, size: 8),
                        SizedBox(width: 5),
                        Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Viewer count badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '$_viewerCount',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // More options (3 dots) + Close
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white, size: 24),
                    onPressed: () {
                      Get.bottomSheet(
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.themeColor,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
                          ),
                          child: SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(leading: Icon(Icons.settings, color: AppTheme.iconscolor), title: Text('Settings', style: TextStyle(color: AppTheme.textPrimary)), onTap: () => Get.back()),
                                ListTile(leading: Icon(Icons.flag, color: AppTheme.iconscolor), title: Text('Report', style: TextStyle(color: AppTheme.textPrimary)), onTap: () => Get.back()),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: _requestExit,
                  ),
                ],
              ),
            ),
          ),
          // Right sidebar: vertical controls (broadcaster only - like reference)
          if (widget.isBroadcaster) ...[
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 70, bottom: 140),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _verticalControl(Icons.mic, _micMuted ? Icons.mic_off : Icons.mic, _micMuted, () async {
                          await AgoraService.muteLocalAudio(!_micMuted);
                          setState(() => _micMuted = !_micMuted);
                        }),
                        const SizedBox(height: 14),
                        _verticalControl(Icons.videocam, _videoMuted ? Icons.videocam_off : Icons.videocam, _videoMuted, () async {
                          await AgoraService.muteLocalVideo(!_videoMuted);
                          setState(() => _videoMuted = !_videoMuted);
                        }),
                        const SizedBox(height: 14),
                        _verticalControl(Icons.cameraswitch, Icons.cameraswitch, false, () async => await AgoraService.switchCamera()),
                        // const SizedBox(height: 14),
                        // _verticalControl(Icons.auto_awesome, Icons.auto_awesome, false, () {}),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
                ]),
              ),
            ),
          // Broadcaster: "We're telling your followers..." banner (dismissible)
          if (widget.isBroadcaster && _showFollowerBanner)
            Positioned(
              left: 12,
              right: 60,
              bottom: 260,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => setState(() => _showFollowerBanner = false),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white70, size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            "We're telling your followers that you've started a live video.",
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                        Icon(Icons.close, color: Colors.white70, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Reactions/comments strip – keyboard open hone pe iske upar uth jata hai, video nahi
          Positioned(
            left: 12,
            right: 12,
            bottom: 150 + keyboardHeight,
            height: 100,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _textComments.isEmpty
                    ? Center(
                        child: Text(
                          'Comments',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        controller: _commentScrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        itemCount: _textComments.length,
                        itemBuilder: (context, index) {
                          final c = _textComments[_textComments.length - 1 - index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: RichText(
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    text: TextSpan(
                                      style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.2),
                                      children: [
                                        TextSpan(text: '${c.userName}: ', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.95))),
                                        TextSpan(text: c.text),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
          // Bottom: emoji + comment input – keyboard open hone pe iske upar uth jata hai
          // This is outside GestureDetector so buttons work properly
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboardHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                // Absorb tap - don't dismiss keyboard when tapping bottom bar area
              },
              child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      // Quick emoji reactions: Fruits screen jaisa — ek fruit per category, tap pe 3 variants
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: _buildQuickReactionRow(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Bottom bar: Add a comment... + action icons (reference style)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: TextField(
                                controller: _commentController,
                                focusNode: _commentFocusNode,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Add a comment...',
                                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onSubmitted: (v) {
                                  _addComment(v);
                                  _commentController.clear();
                                  FocusScope.of(context).unfocus();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // _bottomBarIcon(Icons.add_photo_alternate_outlined, () {}),
                              // _bottomBarIcon(Icons.group_add_outlined, () {}),
                              // _bottomBarIcon(Icons.help_outline, () {}),
                              _bottomBarIcon(Icons.send_rounded, () {
                                final t = _commentController.text.trim();
                                if (t.isNotEmpty) {
                                  _addComment(t);
                                  _commentController.clear();
                                  FocusScope.of(context).unfocus();
                                }
                              }),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    ),
      ),
    ])));
  }

  Widget _buildHostEndedOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off_rounded, size: 72, color: Colors.white54),
              const SizedBox(height: 20),
              const Text(
                'Live video ended',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'The host has ended this live.',
                style: TextStyle(color: Colors.white70, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back, size: 20),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMD)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Row: fruit tap = us fruit ke 3 variants; corner me diagonal arrow (bina black), arrow tap bhi variants
  List<Widget> _buildQuickReactionRow() {
    final byFruitType = _groupEmojisByFruitType(_quickFruitEmojis);
    if (byFruitType.isEmpty) return [];
    return byFruitType.entries.map((e) {
      final variants = e.value;
      final first = variants.first;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.none,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _showVariantOverlay(variants),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _buildQuickReactionItem(first),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showVariantOverlay(variants),
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Transform.rotate(
                          angle: -0.785,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildQuickReactionItem(Map<String, dynamic> data) {
    final emojiChar = data['emoji_char'] as String? ?? '';
    final imageUrl = data['image_url'] as String? ?? '';
    if (emojiChar.isNotEmpty) return Text(emojiChar, style: const TextStyle(fontSize: 24));
    if (imageUrl.isNotEmpty) {
      return SizedBox(
        width: 32,
        height: 32,
        child: CachedImage(imageUrl: imageUrl, fit: BoxFit.contain, width: 32, height: 32),
      );
    }
    return const SizedBox(width: 32, height: 32);
  }

  Widget _buildFloatingEmoji(Map<String, dynamic> data, int id) {
    final offsetX = ((id % 7) - 3) * 28.0;
    final emojiChar = data['emoji_char'] as String? ?? '';
    final imageUrl = data['image_url'] as String? ?? '';
    Widget content;
    if (emojiChar.isNotEmpty) {
      content = Text(emojiChar, style: const TextStyle(fontSize: 44));
    } else if (imageUrl.isNotEmpty) {
      content = SizedBox(
        width: 48,
        height: 48,
        child: CachedImage(imageUrl: imageUrl, fit: BoxFit.contain, width: 48, height: 48),
      );
    } else {
      content = const Icon(Icons.favorite, color: Colors.pink, size: 44);
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey('float_$id'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 2000),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Positioned(
          left: 0,
          right: 0,
          bottom: 120 + (200 * value),
          child: Transform.translate(
            offset: Offset(offsetX, 0),
            child: Center(
              child: Opacity(opacity: 1 - value, child: content),
            ),
          ),
        );
      },
    );
  }

  Widget _verticalControl(IconData iconOff, IconData iconOn, bool isMuted, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.2),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(isMuted ? iconOn : iconOff, color: Colors.white, size: 26),
        ),
      ),
    );
  }

  Widget _bottomBarIcon(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
