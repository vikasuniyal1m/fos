import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fruitsofspirit/controllers/shorts_controller.dart';
import 'package:fruitsofspirit/services/shorts_service.dart';
import 'package:fruitsofspirit/services/short_video_preload_service.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/utils/share_helper.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/widgets/short_comments_sheet.dart';
import 'package:fruitsofspirit/routes/routes.dart';
import 'package:fruitsofspirit/controllers/home_controller.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';

/// Vertical Shorts feed — TikTok/Reels-style standalone screen
class ShortsScreen extends StatefulWidget {
  const ShortsScreen({Key? key}) : super(key: key);

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  late final ShortsController controller;
  late final PageController _pageController;
  final Map<int, VideoPlayerController> _players = {};
  final Set<int> _initializingPlayers = {};
  int _currentIndex = 0;
  String _feedMode = 'community';

  static const Color _gold = Color(0xFFD4AF37);
  final _preload = ShortVideoPreloadService.instance;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<ShortsController>()
        ? Get.find<ShortsController>()
        : Get.put(ShortsController());
    final args = Get.arguments as Map<String, dynamic>? ?? {};
    _feedMode = args['mode']?.toString() ?? 'community';
    _currentIndex = args['startIndex'] as int? ?? 0;
    _pageController = PageController(initialPage: _currentIndex);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bootstrapFeedSync(args);
      _startPlayback();
    });
  }

  void _bootstrapFeedSync(Map<String, dynamic> args) {
    if (args['prepared'] == true) {
      controller.startPolling();
      return;
    }

    final seed = _parseSeed(args['seed']);
    controller.bootstrapFeedCache(_feedMode);

    if (_feedMode == 'saved') {
      controller.useSavedFeed(seed: seed);
      unawaited(controller.loadSavedShorts().then((_) {
        if (seed == null || seed.isEmpty) controller.useSavedFeed();
      }));
    } else if (_feedMode == 'mine') {
      controller.useMyFeed(seed: seed);
      unawaited(controller.loadMyShorts(refresh: true, silent: controller.shorts.isNotEmpty));
    } else {
      controller.useCommunityFeed(seed: seed);
      if ((seed == null || seed.isEmpty) && Get.isRegistered<HomeController>()) {
        controller.seedCommunityFromHome(
          Get.find<HomeController>().communityShorts.toList(),
        );
      }
      unawaited(controller.loadCommunityShorts(refresh: true, silent: controller.shorts.isNotEmpty));
    }
    controller.startPolling();
  }

  void _startPlayback() {
    if (controller.shorts.isEmpty) return;
    _warmPlayersAround(_currentIndex);
    unawaited(_initPlayer(_currentIndex, autoplay: true));
  }

  void _warmPlayersAround(int index) {
    if (controller.shorts.isEmpty) return;
    _preload.warmCacheForShorts(controller.shorts.toList(), focusIndex: index);
    for (final offset in [-1, 1, 2]) {
      final target = index + offset;
      if (target >= 0 && target < controller.shorts.length) {
        unawaited(_initPlayer(target));
      }
    }
  }

  List<Map<String, dynamic>>? _parseSeed(dynamic raw) {
    if (raw is! List || raw.isEmpty) return null;
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    controller.stopPolling();
    _disposeAllPlayers();
    _pageController.dispose();
    super.dispose();
  }

  void _disposeAllPlayers() {
    for (final p in _players.values) {
      p.dispose();
    }
    _players.clear();
  }

  void _disposePlayerAt(int index) {
    _players.remove(index)?.dispose();
  }

  void _disposeDistantPlayers(int activeIndex) {
    final keep = {
      activeIndex - 1,
      activeIndex,
      activeIndex + 1,
    };
    for (final index in _players.keys.toList()) {
      if (!keep.contains(index)) {
        _disposePlayerAt(index);
      }
    }
  }

  Future<void> _initPlayer(int index, {bool autoplay = false}) async {
    if (index < 0 || index >= controller.shorts.length) return;
    if (_players.containsKey(index) || _initializingPlayers.contains(index)) return;

    final url = ShortsService.getVideoUrl(controller.shorts[index]);
    if (url == null || url.isEmpty) return;

    _initializingPlayers.add(index);
    final player = await _preload.createInitializedPlayer(url);
    _initializingPlayers.remove(index);
    if (!mounted || player == null) {
      await player?.dispose();
      return;
    }

    _players[index] = player;
    if (autoplay || _currentIndex == index) {
      await player.play();
    }
    if (mounted) setState(() {});
  }

  void _onPageChanged(int index) {
    _players[_currentIndex]?.pause();
    _currentIndex = index;
    final player = _players[index];
    if (player != null && player.value.isInitialized) {
      unawaited(player.play());
    } else {
      unawaited(_initPlayer(index, autoplay: true));
    }
    unawaited(controller.recordView(index));
    _warmPlayersAround(index);
    _disposeDistantPlayers(index);
    if (mounted) setState(() {});

    if (_feedMode != 'saved' &&
        index >= controller.shorts.length - 3 &&
        controller.hasMore.value) {
      if (_feedMode == 'mine') {
        unawaited(controller.loadMyShorts());
      } else {
        unawaited(controller.loadCommunityShorts());
      }
    }
  }

  void _pauseAllPlayers() {
    for (final p in _players.values) {
      if (p.value.isInitialized && p.value.isPlaying) {
        p.pause();
      }
    }
  }

  void _resumeCurrentPlayer() {
    final player = _players[_currentIndex];
    if (player != null && player.value.isInitialized && !player.value.isPlaying) {
      unawaited(player.play());
    }
  }

  Future<void> _openUpload() async {
    _pauseAllPlayers();
    await Get.toNamed(Routes.UPLOAD_SHORT);
    if (mounted) _resumeCurrentPlayer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (controller.shorts.isEmpty && controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: _gold));
        }
        if (controller.shorts.isEmpty) {
          return _buildEmptyState();
        }
        return Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: controller.shorts.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                return _ShortPage(
                  short: controller.shorts[index],
                  index: index,
                  player: _players[index],
                  isActive: index == _currentIndex,
                  isBuffering: _initializingPlayers.contains(index),
                  gold: _gold,
                  onLike: () => controller.toggleLike(index),
                  onSave: () => controller.toggleSave(index),
                  onComment: () => _openComments(index),
                  onShare: () => _shareShort(index),
                  onMore: () => _showMoreOptions(index),
                );
              },
            ),
            _buildTopBar(context),
            if (controller.isSilentSyncing.value)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: _gold,
                  backgroundColor: Colors.transparent,
                ),
              ),
          ],
        );
      }),
      floatingActionButton: _feedMode == 'saved'
          ? null
          : FloatingActionButton(
              onPressed: _openUpload,
              backgroundColor: _gold,
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  String get _feedTitle {
    switch (_feedMode) {
      case 'mine':
        return 'My Grace Moments';
      case 'saved':
        return 'Saved Grace Moments';
      default:
        return 'Grace Moments';
    }
  }

  Widget _buildTopBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: ResponsiveHelper.padding(context, horizontal: 12, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Get.back(),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.play_circle_outline, color: _gold, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _feedTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Future<T?> _showShortsThemedSheet<T>({
    required String title,
    required IconData headerIcon,
    required List<Widget> children,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppTheme.themeColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: _gold.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(headerIcon, color: _gold, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: ResponsiveHelper.textStyle(
                          context,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: _gold.withOpacity(0.25)),
              ...children,
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? _gold),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_outline, color: Colors.white54, size: 64),
          const SizedBox(height: 16),
          const Text('No grace moments yet', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _openUpload,
            style: ElevatedButton.styleFrom(backgroundColor: _gold),
            child: const Text('Upload Grace Moment', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openComments(int index) {
    _pauseAllPlayers();
    final short = controller.shorts[index];
    final shortId = ShortsService.shortId(short);
    final commentCount =
        int.tryParse(short['total_comments']?.toString() ?? '0') ?? 0;
    controller.bootstrapComments(shortId);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShortCommentsSheet(
        shortId: shortId,
        feedIndex: index,
        commentCount: commentCount,
        controller: controller,
      ),
    ).then((_) {
      if (mounted) _resumeCurrentPlayer();
    });
  }

  Future<void> _shareShort(int index) async {
    final short = controller.shorts[index];
    final id = ShortsService.shortId(short);
    final title = short['title']?.toString() ?? 'Grace Moment';
    final description = short['description']?.toString();
    final mediaUrl = ShortsService.getVideoUrl(short);

    await _showShortsThemedSheet(
      title: 'Share Grace Moment',
      headerIcon: Icons.share_outlined,
      children: [
        _sheetTile(
          icon: Icons.link,
          title: 'Copy Link',
          onTap: () async {
            Navigator.pop(context);
            final link = 'https://fosmessenger.com/share/short/$id';
            await Clipboard.setData(ClipboardData(text: link));
            unawaited(controller.trackShare(index, shareType: 'copy_link'));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied')),
              );
            }
          },
        ),
        _sheetTile(
          icon: Icons.share,
          title: 'Share',
          onTap: () async {
            Navigator.pop(context);
            await ShareHelper.shareContent(
              contentType: 'short',
              contentId: id,
              title: title,
              content: description,
              mediaUrl: mediaUrl,
              context: context,
            );
            unawaited(controller.trackShare(index, shareType: 'native'));
          },
        ),
        _sheetTile(
          icon: Icons.send_outlined,
          title: 'Share in App',
          onTap: () async {
            Navigator.pop(context);
            unawaited(controller.trackShare(index, shareType: 'internal'));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share tracked')),
              );
            }
          },
        ),
      ],
    );
  }

  void _showMoreOptions(int index) async {
    final short = controller.shorts[index];
    final shortId = ShortsService.shortId(short);
    final ownerId = int.tryParse(short['user_id']?.toString() ?? '0') ?? 0;
    final currentUserId = await UserStorage.getUserId() ?? 0;
    final isOwner = ownerId == currentUserId;

    if (!mounted) return;
    _showShortsThemedSheet(
      title: 'Grace Moment Options',
      headerIcon: Icons.play_circle_outline,
      children: [
        if (isOwner)
          _sheetTile(
            icon: Icons.delete_outline,
            title: 'Delete Grace Moment',
            iconColor: Colors.red,
            titleColor: Colors.red,
            onTap: () async {
              Navigator.pop(context);
              final confirm = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  backgroundColor: AppTheme.themeColor,
                  title: const Text('Delete Grace Moment?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(d, true),
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await controller.deleteOwnShort(shortId, index);
              }
            },
          )
        else
          _sheetTile(
            icon: Icons.flag_outlined,
            title: 'Report',
            onTap: () {
              Navigator.pop(context);
              _showReportDialog(shortId);
            },
          ),
      ],
    );
  }

  void _showReportDialog(int shortId) {
    const reasons = ['Spam', 'Harassment', 'Inappropriate Content', 'Copyright', 'Other'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Grace Moment'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: reasons.map((r) => ListTile(
              title: Text(r),
              onTap: () async {
                Navigator.pop(ctx);
                await controller.reportShort(shortId, r);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted')),
                  );
                }
              },
            )).toList(),
          ),
        ),
      ),
    );
  }
}

class _ShortPage extends StatefulWidget {
  final Map<String, dynamic> short;
  final int index;
  final VideoPlayerController? player;
  final bool isActive;
  final bool isBuffering;
  final Color gold;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onMore;

  const _ShortPage({
    required this.short,
    required this.index,
    required this.player,
    required this.isActive,
    this.isBuffering = false,
    required this.gold,
    required this.onLike,
    required this.onSave,
    required this.onComment,
    required this.onShare,
    required this.onMore,
  });

  @override
  State<_ShortPage> createState() => _ShortPageState();
}

class _ShortPageState extends State<_ShortPage> {
  static const _controlsHideDelay = Duration(seconds: 3);

  bool _controlsVisible = true;
  bool _isPaused = false;
  bool _isScrubbing = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.player?.addListener(_onPlayerTick);
    if (widget.isActive) _scheduleHideControls();
  }

  @override
  void didUpdateWidget(covariant _ShortPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      oldWidget.player?.removeListener(_onPlayerTick);
      widget.player?.addListener(_onPlayerTick);
    }
    if (widget.isActive && !oldWidget.isActive) {
      _isPaused = false;
      _controlsVisible = true;
      _scheduleHideControls();
    } else if (!widget.isActive && oldWidget.isActive) {
      _hideTimer?.cancel();
      _controlsVisible = false;
      _isPaused = false;
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.player?.removeListener(_onPlayerTick);
    super.dispose();
  }

  void _onPlayerTick() {
    if (!mounted || _isScrubbing) return;
    setState(() {});
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    if (!widget.isActive || _isPaused) return;
    _hideTimer = Timer(_controlsHideDelay, () {
      if (mounted && widget.isActive && !_isPaused && !_isScrubbing) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _revealControls({bool reschedule = true}) {
    setState(() => _controlsVisible = true);
    if (reschedule && !_isPaused) _scheduleHideControls();
  }

  void _togglePlayPause() {
    final player = widget.player;
    if (player == null || !player.value.isInitialized) return;

    if (player.value.isPlaying) {
      player.pause();
      setState(() {
        _isPaused = true;
        _controlsVisible = true;
      });
      _hideTimer?.cancel();
    } else {
      player.play();
      setState(() => _isPaused = false);
      _revealControls();
    }
  }

  void _onVideoTap() {
    if (!_controlsVisible) {
      _revealControls();
      return;
    }
    _togglePlayPause();
  }

  void _seekRelative(Duration offset) {
    final player = widget.player;
    if (player == null || !player.value.isInitialized) return;
    final duration = player.value.duration;
    var target = player.value.position + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (target > duration) target = duration;
    player.seekTo(target);
    _revealControls();
  }

  @override
  Widget build(BuildContext context) {
    final short = widget.short;
    final player = widget.player;
    final thumb = ShortsService.getThumbnailUrl(short);
    final isLiked = short['is_liked'] == true;
    final isSaved = short['is_saved'] == true;
    final likes = int.tryParse(short['total_likes']?.toString() ?? '0') ?? 0;
    final comments = int.tryParse(short['total_comments']?.toString() ?? '0') ?? 0;
    final shares = int.tryParse(short['total_shares']?.toString() ?? '0') ?? 0;
    final userName = short['user_name']?.toString() ?? 'User';
    final title = short['title']?.toString() ?? '';
    final description = short['description']?.toString() ?? '';

    final initialized = player != null && player.value.isInitialized;
    final durationMs = initialized ? player.value.duration.inMilliseconds : 0;
    final positionMs = initialized ? player.value.position.inMilliseconds : 0;
    final maxMs = durationMs > 0 ? durationMs.toDouble() : 1.0;
    final showPlayOverlay = widget.isActive &&
        _controlsVisible &&
        initialized &&
        (_isPaused || !player!.value.isPlaying);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (initialized)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: player!.value.size.width,
              height: player.value.size.height,
              child: VideoPlayer(player),
            ),
          )
        else if (thumb != null)
          CachedNetworkImage(
            imageUrl: thumb,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: Colors.grey.shade900),
          )
        else
          Container(color: Colors.grey.shade900),

        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.isActive ? _onVideoTap : null,
            onDoubleTapDown: widget.isActive
                ? (details) {
                    final w = context.size?.width ?? MediaQuery.sizeOf(context).width;
                    if (details.localPosition.dx < w * 0.35) {
                      _seekRelative(const Duration(seconds: -5));
                    } else if (details.localPosition.dx > w * 0.65) {
                      _seekRelative(const Duration(seconds: 5));
                    }
                  }
                : null,
          ),
        ),

        if (widget.isBuffering && thumb == null)
          Container(
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
            ),
          )
        else if (widget.isBuffering)
          const Positioned(
            top: 48,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              color: Colors.white70,
              backgroundColor: Colors.transparent,
            ),
          ),

        if (showPlayOverlay)
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPaused || !player!.value.isPlaying
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),

        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withOpacity(0.7), Colors.transparent],
              stops: const [0.0, 0.5],
            ),
          ),
        ),

        Positioned(
          right: 12,
          bottom: 100,
          child: Column(
            children: [
              _ActionButton(
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                label: ShortsService.formatCount(likes),
                color: isLiked ? Colors.red : Colors.white,
                onTap: widget.onLike,
              ),
              const SizedBox(height: 20),
              _ActionButton(
                icon: Icons.chat_bubble_outline,
                label: ShortsService.formatCount(comments),
                onTap: widget.onComment,
              ),
              const SizedBox(height: 20),
              _ActionButton(
                icon: Icons.share,
                label: shares > 0 ? ShortsService.formatCount(shares) : 'Share',
                onTap: widget.onShare,
              ),
              const SizedBox(height: 20),
              _ActionButton(
                icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                label: isSaved ? 'Saved' : 'Save',
                color: isSaved ? widget.gold : Colors.white,
                onTap: widget.onSave,
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: widget.onMore,
                child: const Icon(Icons.more_vert, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),

        Positioned(
          left: 16,
          right: 80,
          bottom: 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${userName.replaceAll(' ', '_').toLowerCase()}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              if (title.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ],
          ),
        ),

        if (widget.isActive && initialized)
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom,
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    activeTrackColor: widget.gold,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: widget.gold,
                    overlayColor: widget.gold.withOpacity(0.2),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                  ),
                  child: Slider(
                    min: 0,
                    max: maxMs,
                    value: positionMs.clamp(0, maxMs.toInt()).toDouble(),
                    onChangeStart: (_) {
                      setState(() {
                        _isScrubbing = true;
                        _controlsVisible = true;
                      });
                      _hideTimer?.cancel();
                    },
                    onChanged: (v) {
                      player!.seekTo(Duration(milliseconds: v.round()));
                    },
                    onChangeEnd: (v) {
                      player!.seekTo(Duration(milliseconds: v.round()));
                      setState(() => _isScrubbing = false);
                      if (!_isPaused) _scheduleHideControls();
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.color = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
