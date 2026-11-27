import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/banners_controller.dart';
import 'package:fruitsofspirit/services/banners_service.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:math' as math;

class BannerCarouselWidget extends StatefulWidget {
  const BannerCarouselWidget({Key? key}) : super(key: key);
  @override
  State<BannerCarouselWidget> createState() => _BannerCarouselWidgetState();
}

class _BannerCarouselWidgetState extends State<BannerCarouselWidget> {
  late final PageController _pageController;
  int _currentPage = 0;
  int _lastBannerCount = 0;
  Timer? _countdownTimer;
  Timer? _autoScrollTimer;
  final Map<String, String> _countdowns = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    try {
      final controller = Get.find<BannersController>();
      _lastBannerCount =
          controller.activeBanners.length + controller.upcomingBanners.length;
      ever(controller.activeBanners, (_) => _onBannerListChanged());
      ever(controller.upcomingBanners, (_) => _onBannerListChanged());
      _startCountdownTimer();
      _scheduleAutoScroll();
    } catch (e) {
      print('❌ BannerWidget: BannersController not found - $e');
    }
  }

  void _onBannerListChanged() {
    if (!mounted) return;
    try {
      final ctrl = Get.find<BannersController>();
      final count = ctrl.activeBanners.length + ctrl.upcomingBanners.length;
      if (count == _lastBannerCount) return;
      _lastBannerCount = count;
      _currentPage = 0;
      if (_pageController.hasClients && count > 0) {
        _pageController.jumpToPage(0);
      }
      _scheduleAutoScroll();
    } catch (_) {}
  }

  void _scheduleAutoScroll() {
    _autoScrollTimer?.cancel();
    if (!mounted) return;
    try {
      final ctrl = Get.find<BannersController>();
      final totalBanners =
          ctrl.activeBanners.length + ctrl.upcomingBanners.length;
      if (totalBanners <= 1) return;
      _autoScrollTimer = Timer(const Duration(seconds: 4), _autoScrollNext);
    } catch (_) {}
  }

  void _autoScrollNext() {
    if (!mounted || !_pageController.hasClients) return;

    try {
      final ctrl = Get.find<BannersController>();
      final totalBanners =
          ctrl.activeBanners.length + ctrl.upcomingBanners.length;
      if (totalBanners <= 1) return;
      _currentPage = (_currentPage + 1) % totalBanners;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      _scheduleAutoScroll();
    } catch (e) {
      print('❌ Error in auto-scroll: $e');
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    if (!mounted) return;
    
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _updateCountdowns();
        });
      }
    });
  }

  void _updateCountdowns() {
    try {
      final controller = Get.find<BannersController>();
      final now = DateTime.now();
      final allBanners = [
        ...controller.activeBanners,
        ...controller.upcomingBanners,
      ];

      for (var banner in allBanners) {
        final endsAt = banner['ends_at'] as String?;

        if (endsAt != null) {
          final endTime = DateTime.parse(endsAt);
          final difference = endTime.difference(now);

          if (difference.isNegative) {
            _countdowns[banner['id'].toString()] = 'Ended';
          } else {
            final days = difference.inDays;
            final hours = difference.inHours % 24;
            final minutes = difference.inMinutes % 60;
            final seconds = difference.inSeconds % 60;

            _countdowns[banner['id'].toString()] = _formatCountdown(
              days,
              hours,
              minutes,
              seconds,
            );
          }
        }
      }
    } catch (e) {
      print('❌ Error updating countdowns: $e');
    }
  }

  String _formatCountdown(int days, int hours, int minutes, int seconds) {
    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m ${seconds}s';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Color _parseBackgroundColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return const Color(0xFFF3F4F6);
    try {
      if (colorStr.startsWith('#')) {
        return Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
      }
      return const Color(0xFFF3F4F6);
    } catch (e) {
      return const Color(0xFFF3F4F6);
    }
  }

  Future<void> _handleBannerAction(String? action) async {
    if (action == null || action.isEmpty) return;
    if (action.startsWith('http://') || action.startsWith('https://')) {
      final uri = Uri.parse(action);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      print('Banner action: $action');
      Get.snackbar('Event', action);
    }
  }

  double _bannerImageHeight(BuildContext context) {
    final width = ResponsiveHelper.screenWidth(context);
    // Height scales with width for all devices to prevent top/bottom cropping
    // 0.54 ratio works well for standard banner images across all screen sizes
    if (ResponsiveHelper.isTablet(context) || ResponsiveHelper.isDesktop(context)) {
      return width * 0.50; 
    }
    return width * 0.54;
  }

  double _pageHeightForBanner(BuildContext context, Map<String, dynamic> banner) {
    final imageHeight = _bannerImageHeight(context);
    final hasCountdown = banner['ends_at'] != null;
    final hasButton = (banner['button_text'] as String? ?? '').isNotEmpty;
    final countdownHeight = ResponsiveHelper.dim(context, mobile: 36, tablet: 44, desktop: 50);
    final buttonHeight = ResponsiveHelper.dim(context, mobile: 42, tablet: 50);
    
    // Match gaps with itemBuilder padding to minimize empty space
    final countdownGap = hasCountdown ? ResponsiveHelper.spacing(context, 4) : 0;
    final buttonGap = hasButton ? ResponsiveHelper.spacing(context, 6) : 0;

    return imageHeight +
        (hasCountdown ? countdownHeight + countdownGap : 0) +
        (hasButton ? buttonHeight + buttonGap : 0) + 4; // Minimal buffer for tight layout
  }

  double _maxPageHeight(BuildContext context, List<Map<String, dynamic>> banners) {
    if (banners.isEmpty) return _bannerImageHeight(context);
    return banners
        .map((banner) => _pageHeightForBanner(context, banner))
        .reduce(math.max);
  }

  EdgeInsets _bannerHorizontalPadding(BuildContext context) {
    // Zero padding for edge-to-edge look to remove side spaces
    return EdgeInsets.zero;
  }

  Widget _buildBannerPlaceholder(BuildContext context) {
    final height = _bannerImageHeight(context);
    return Padding(
      padding: _bannerHorizontalPadding(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 20),
        ),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF8B4513), Color(0xFFA0522D)],
              ),
            ),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      final bannersCtrl = Get.find<BannersController>();
      return Obx(() {
        final banners = bannersCtrl.activeBanners;
        final upcoming = bannersCtrl.upcomingBanners;
        final allBanners = [...banners, ...upcoming];

        if (!mounted) return const SizedBox.shrink();

        if (allBanners.isEmpty) {
          if (!bannersCtrl.hasInitialLoad.value) {
            return _buildBannerPlaceholder(context);
          }
          return const SizedBox.shrink();
        }

        if (allBanners.any((banner) => banner == null || banner.isEmpty)) {
          return const SizedBox.shrink();
        }

        final imageHeight = _bannerImageHeight(context);
        final pageHeight = _maxPageHeight(context, allBanners);

        return Column(
          children: [
            SizedBox(
              height: pageHeight,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) {
                  if (mounted) {
                    setState(() => _currentPage = i);
                  }
                },
                itemCount: allBanners.length,
                itemBuilder: (context, index) {
                  if (index >= allBanners.length) {
                    return const SizedBox.shrink();
                  }
                  final b = allBanners[index];
                  final url = BannersService.getBannerImageUrl(b['file_path'] ?? '');
                  final buttonText = b['button_text'] as String? ?? '';
                  final buttonAction = b['button_action'] as String? ?? '';
                  final bgColor = _parseBackgroundColor(b['background_color'] as String?);
                  final isPromotional = buttonText.isNotEmpty;
                  final endsAt = b['ends_at'] as String?;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: _bannerHorizontalPadding(context),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            ResponsiveHelper.borderRadius(context, mobile: 16, tablet: 20),
                          ),
                          child: GestureDetector(
                            onTap: isPromotional ? () => _handleBannerAction(buttonAction) : null,
                            child: Container(
                              height: imageHeight,
                              width: double.infinity,
                              color: bgColor,
                              child: url.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: url,
                                      fit: BoxFit.cover, // Back to cover for full-width look
                                      alignment: Alignment.center,
                                      width: double.infinity,
                                      height: imageHeight,
                                      fadeInDuration: Duration.zero,
                                      fadeOutDuration: Duration.zero,
                                      placeholder: (_, __) => ColoredBox(
                                        color: bgColor == Colors.white
                                            ? const Color(0xFF8B4513).withOpacity(0.15)
                                            : bgColor,
                                      ),
                                      errorWidget: (_, __, ___) => ColoredBox(
                                        color: bgColor,
                                        child: Icon(
                                          Icons.image_not_supported_outlined,
                                          color: Colors.grey.shade400,
                                          size: ResponsiveHelper.dim(context, mobile: 36, tablet: 42),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      if (endsAt != null)
                        Padding(
                          padding: EdgeInsets.only(top: ResponsiveHelper.spacing(context, 4)),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _buildLiveCountdown(
                              context,
                              b['id'].toString(),
                              b['starts_at'] as String?,
                            ),
                          ),
                        ),
                      if (buttonText.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(
                            top: ResponsiveHelper.spacing(context, 6),
                          ).add(_bannerHorizontalPadding(context)),
                          child: SizedBox(
                            width: double.infinity,
                            height: ResponsiveHelper.buttonHeight(context, mobile: 40, tablet: 48),
                            child: ElevatedButton(
                              onPressed: () => _handleBannerAction(buttonAction),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF667EEA),
                                padding: ResponsiveHelper.padding(
                                  context,
                                  horizontal: ResponsiveHelper.isMobile(context) ? 24 : 32,
                                  vertical: ResponsiveHelper.isMobile(context) ? 10 : 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    ResponsiveHelper.borderRadius(context, mobile: 25),
                                  ),
                                ),
                                elevation: ResponsiveHelper.dim(context, mobile: 4, tablet: 6),
                                shadowColor: Colors.black.withOpacity(0.2),
                              ),
                              child: Text(
                                buttonText.toUpperCase(),
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            if (allBanners.length > 1)
              Padding(
                padding: EdgeInsets.only(
                  top: ResponsiveHelper.spacing(context, 4), // Reduced gap between content and dots
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    allBanners.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: EdgeInsets.symmetric(
                        horizontal: ResponsiveHelper.spacing(context, 4),
                      ),
                      width: _currentPage == i
                          ? ResponsiveHelper.dim(context, mobile: 16, tablet: 24, desktop: 28)
                          : ResponsiveHelper.dim(context, mobile: 6, tablet: 10, desktop: 12),
                      height: ResponsiveHelper.dim(context, mobile: 6, tablet: 10, desktop: 12),
                      decoration: BoxDecoration(
                        color: _currentPage == i
                            ? const Color(0xFF6C5CE7).withOpacity(0.75)
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(
                          ResponsiveHelper.dim(context, mobile: 3, tablet: 5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      });
    } catch (e) {
      print('❌ BannerWidget Error: $e');
      return const SizedBox.shrink();
    }
  }

  Widget _buildLiveCountdown(BuildContext context, String bannerId, String? startsAt) {
    final countdownText = _countdowns[bannerId] ?? 'Loading...';

    if (countdownText == 'Ended' || countdownText == 'Loading...') {
      return const SizedBox.shrink();
    }

    final isUpcoming = startsAt != null && DateTime.parse(startsAt).isAfter(DateTime.now());
    final labelText = isUpcoming ? 'Starts in ' : 'Ends in ';
    final iconData = isUpcoming ? Icons.schedule : Icons.timer_outlined;

    return Container(
      constraints: BoxConstraints(
        maxWidth: ResponsiveHelper.screenWidth(context) -
            ResponsiveHelper.dim(context, mobile: 32, tablet: 60),
      ),
      padding: ResponsiveHelper.padding(
        context,
        horizontal: ResponsiveHelper.dim(context, mobile: 12, tablet: 18),
        vertical: ResponsiveHelper.dim(context, mobile: 6, tablet: 10),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUpcoming
              ? [const Color(0xFF667EEA), const Color(0xFF764BA2)]
              : [const Color(0xFFFF5F6D), const Color(0xFFFFC371)],
        ),
        borderRadius: BorderRadius.circular(
          ResponsiveHelper.borderRadius(context, mobile: 25, tablet: 35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: ResponsiveHelper.dim(context, mobile: 8, tablet: 12),
            offset: Offset(0, ResponsiveHelper.dim(context, mobile: 4, tablet: 6)),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            iconData,
            color: Colors.white,
            size: ResponsiveHelper.iconSize(context, mobile: 13, tablet: 18, desktop: 20),
          ),
          SizedBox(width: ResponsiveHelper.spacing(context, 8)),
          Text(
            '$labelText$countdownText',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 11, tablet: 14, desktop: 16),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
