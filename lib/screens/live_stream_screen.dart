import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:get/get.dart';
import '../services/agora_service.dart';
import '../services/live_streaming_service.dart';
import '../utils/responsive_helper.dart';
import '../services/comments_service.dart';
import '../services/user_storage.dart';

class LiveStreamScreen extends StatefulWidget {
  final Map<String, dynamic> streamData;
  final bool isBroadcaster;

  const LiveStreamScreen({
    Key? key,
    required this.streamData,
    required this.isBroadcaster,
  }) : super(key: key);

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  late RtcEngine _engine;
  bool _localUserJoined = false;
  int? _remoteUid;
  bool _isLoading = true;
  final List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  bool _isSendingComment = false;

  @override
  void initState() {
    super.initState();
    _initAgora();
    _loadComments();
  }

  Future<void> _initAgora() async {
    try {
      final appId = widget.streamData['agora_app_id']?.toString() ?? '';
      final token = widget.streamData['agora_token']?.toString() ?? '';
      final channelName = widget.streamData['channel_name']?.toString() ?? '';

      if (appId.isEmpty || channelName.isEmpty) {
        throw Exception('Invalid stream configuration');
      }

      _engine = await AgoraService.initEngine(appId);

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint("local user ${connection.localUid} joined");
            setState(() {
              _localUserJoined = true;
              _isLoading = false;
            });
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint("remote user $remoteUid joined");
            setState(() {
              _remoteUid = remoteUid;
            });
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint("remote user $remoteUid left channel");
            setState(() {
              _remoteUid = null;
            });
            if (!widget.isBroadcaster) {
              Get.back();
              Get.snackbar('Stream Ended', 'The broadcaster has ended the stream.');
            }
          },
          onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
            debugPrint('[onTokenPrivilegeWillExpire] connection: ${connection.toJson()}, token: $token');
          },
        ),
      );

      if (widget.isBroadcaster) {
        await AgoraService.joinChannelAsBroadcaster(
          token: token,
          channelName: channelName,
          uid: 0,
        );
        // Update stream status to Live in backend
        await LiveStreamingService.updateStreamStatus(
          streamId: widget.streamData['id'],
          status: 'Live',
        );
      } else {
        await AgoraService.joinChannelAsAudience(
          token: token,
          channelName: channelName,
          uid: 0,
        );
      }
    } catch (e) {
      debugPrint('Error initializing Agora: $e');
      Get.back();
      Get.snackbar('Error', 'Failed to join live stream: $e');
    }
  }

  Future<void> _loadComments() async {
    try {
      final comments = await CommentsService.getComments(
        postType: 'live_video',
        postId: widget.streamData['id'] as int,
      );
      if (mounted) {
        setState(() {
          _comments.clear();
          _comments.addAll(comments.cast<Map<String, dynamic>>());
        });
      }
    } catch (e) {
      debugPrint('Error loading comments: $e');
    }
    
    // Refresh comments every 5 seconds
    if (mounted) {
      Future.delayed(const Duration(seconds: 5), () => _loadComments());
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSendingComment) return;

    setState(() => _isSendingComment = true);

    try {
      final userId = await UserStorage.getUserId();
      if (userId == null) throw Exception('Not logged in');

      await CommentsService.addComment(
        userId: userId,
        postType: 'live_video',
        postId: widget.streamData['id'],
        content: text,
      );

      _commentController.clear();
      _loadComments();
    } catch (e) {
      Get.snackbar('Error', 'Failed to send comment: $e');
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    if (widget.isBroadcaster) {
      // Update stream status to Ended in backend
      LiveStreamingService.updateStreamStatus(
        streamId: widget.streamData['id'],
        status: 'Ended',
      ).catchError((e) => debugPrint('Error ending stream: $e'));
    }
    AgoraService.leaveAndDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _remoteVideo(),
          ),
          if (widget.isBroadcaster)
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 100,
                height: 150,
                child: Center(
                  child: _localUserJoined
                      ? AgoraVideoView(
                          controller: VideoViewController(
                            rtcEngine: _engine,
                            canvas: const VideoCanvas(uid: 0),
                          ),
                        )
                      : const CircularProgressIndicator(),
                ),
              ),
            ),
          _buildOverlay(),
        ],
      ),
    );
  }

  Widget _remoteVideo() {
    if (widget.isBroadcaster) {
      return _localUserJoined
          ? AgoraVideoView(
              controller: VideoViewController(
                rtcEngine: _engine,
                canvas: const VideoCanvas(uid: 0),
              ),
            )
          : const CircularProgressIndicator();
    } else {
      if (_remoteUid != null) {
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _engine,
            canvas: VideoCanvas(uid: _remoteUid),
            connection: RtcConnection(channelId: widget.streamData['channel_name']),
          ),
        );
      } else {
        return const Text(
          'Waiting for broadcaster...',
          style: TextStyle(color: Colors.white),
        );
      }
    }
  }

  Widget _buildOverlay() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.streamData['title'] ?? 'Live Stream',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.streamData['user_name'] != null)
                      Text(
                        'by ${widget.streamData['user_name']}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Comments section
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _comments.length,
              itemBuilder: (context, index) {
                final comment = _comments[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${comment['user_name'] ?? 'User'}: ',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: comment['content'] ?? '',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Say something...',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: IconButton(
                    icon: _isSendingComment
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendComment,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
