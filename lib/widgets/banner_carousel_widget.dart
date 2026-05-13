import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/banners_controller.dart';
import 'package:fruitsofspirit/services/banners_service.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import 'dart:async';

class BannerCarouselWidget extends StatefulWidget {
  const BannerCarouselWidget({Key? key}) : super(key: key);
  @override
  State<BannerCarouselWidget> createState() => _BannerCarouselWidgetState();
}

class _BannerCarouselWidgetState extends State<BannerCarouselWidget> {
  PageController? _pageController;
  int _currentPage = 0;
  Timer? _countdownTimer;
  Map<String, String> _countdowns = {};

  @override
  void initState() {
    super.initState();
    try {
      final controller = Get.find<BannersController>();
      print('🎯 BannerWidget: BannersController found');
      ever(controller.activeBanners, (_) => _startAutoScroll());
      _startCountdownTimer();
    } catch (e) {
      print('❌ BannerWidget: BannersController not found - $e');
    }
  }

  void _startAutoScroll() {
    if (!mounted) return;
    
    _pageController?.dispose();
    try {
      final ctrl = Get.find<BannersController>();
      final totalBanners =
          ctrl.activeBanners.length + ctrl.upcomingBanners.length;
      if (totalBanners <= 1) return;
      _pageController = PageController(initialPage: _currentPage);
      Future.delayed(const Duration(seconds: 4), _autoScrollNext);
    } catch (e) {
      print('❌ Error starting auto-scroll: $e');
    }
  }

  void _autoScrollNext() {
    if (!mounted || _pageController == null || !_pageController!.hasClients)
      return;
    
    try {
      final ctrl = Get.find<BannersController>();
      final totalBanners =
          ctrl.activeBanners.length + ctrl.upcomingBanners.length;
      if (totalBanners <= 1) return;
      _currentPage = (_currentPage + 1) % totalBanners;
      _pageController!.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      Future.delayed(const Duration(seconds: 4), _autoScrollNext);
    } catch (e) {
      print('❌ Error in auto-scroll: $e');
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
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
        final startsAt = banner['starts_at'] as String?;

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
    if (colorStr == null || colorStr.isEmpty) return const Color(0xFF1A1A1A);
    try {
      if (colorStr.startsWith('#')) {
        return Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
      }
      return const Color(0xFF1A1A1A);
    } catch (e) {
      return const Color(0xFF1A1A1A);
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

  @override
  Widget build(BuildContext context) {
    try {
      final bannersCtrl = Get.find<BannersController>();
      return Obx(() {
        final banners = bannersCtrl.activeBanners;
        final upcoming = bannersCtrl.upcomingBanners;
        // Combine both active and upcoming banners
        final allBanners = [...banners, ...upcoming];

        if (allBanners.isEmpty || !mounted) {
          // Return empty widget when no banners are available or widget is not mounted
          return const SizedBox.shrink();
        }

        // Ensure we have valid banner data before creating PageView
        if (allBanners.any((banner) => banner == null || banner.isEmpty)) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            SizedBox(
              height: ResponsiveHelper.isMobile(context) ? 160.0 : 200.0,
              child: PageView.builder(
                controller: _pageController ?? PageController(),
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
                  final url = BannersService.getBannerImageUrl(
                    b['file_path'] ?? '',
                  );
                  final title = b['title'] as String? ?? '';
                  final description = b['description'] as String? ?? '';
                  final buttonText = b['button_text'] as String? ?? '';
                  final buttonAction = b['button_action'] as String? ?? '';
                  final bgColor = _parseBackgroundColor(
                    b['background_color'] as String?,
                  );
                  final isPromotional = buttonText.isNotEmpty;
                  final endsAt = b['ends_at'] as String?;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: ResponsiveHelper.isMobile(context) ? 160.0 : 200.0,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveHelper.isMobile(context) ? 12 : 16,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              ResponsiveHelper.borderRadius(
                                context,
                                mobile: 16,
                                tablet: 20,
                              ),
                            ),
                            child: GestureDetector(
                            onTap: isPromotional
                                ? () => _handleBannerAction(buttonAction)
                                : null,
                            child: Stack(
                              fit: StackFit.loose,
                              children: [
                                // Banner image
                                if (url.isNotEmpty)
                                  CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.contain,
                                    placeholder: (_, __) => Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            bgColor,
                                            bgColor.withOpacity(0.1),
                                          ],
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            bgColor,
                                            bgColor.withOpacity(0.1),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          const Color(0xFF667EEA),
                                          const Color(0xFF764BA2),
                                        ],
                                      ),
                                    ),
                                  ),
                                // Content overlay at bottom
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: EdgeInsets.all(
                                      ResponsiveHelper.isMobile(context) ? 12 : 16,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Countdown timer
                                        if (endsAt != null)
                                          Flexible(
                                            child: _buildLiveCountdown(
                                              context,
                                              b['id'].toString(),
                                              b['starts_at'] as String?,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                      // Action button outside banner container
                      if (buttonText.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(
                            top: ResponsiveHelper.spacing(context, 12),
                            left: ResponsiveHelper.isMobile(context) ? 16 : 20,
                            right: ResponsiveHelper.isMobile(context) ? 16 : 20,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: ResponsiveHelper.isMobile(context) ? 50 : 60,
                            child: ElevatedButton(
                              onPressed: () => _handleBannerAction(buttonAction),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF667EEA),
                                padding: EdgeInsets.symmetric(
                                  horizontal: ResponsiveHelper.isMobile(context) ? 24 : 32,
                                  vertical: ResponsiveHelper.isMobile(context) ? 12 : 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 4,
                                shadowColor: Colors.black.withOpacity(0.2),
                              ),
                              child: Text(
                                buttonText.toUpperCase(),
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: ResponsiveHelper.fontSize(
                                    context,
                                    mobile: 14,
                                    tablet: 16,
                                  ),
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
            // Dot indicators for active banners
            if (allBanners.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    allBanners.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == i ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == i
                            ? const Color(0xFF6C5CE7)
                            : Colors.grey[400],
                        borderRadius: BorderRadius.circular(4),
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

  Widget _buildUpcomingBanner(
    BuildContext context,
    BannersController ctrl,
    Map<String, dynamic> upcoming,
  ) {
    final url = BannersService.getBannerImageUrl(upcoming['file_path'] ?? '');
    final title = upcoming['title'] as String? ?? '';
    final startsAt = DateTime.parse(upcoming['starts_at']);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveHelper.isMobile(context) ? 16 : 20,
      ),
      child: Container(
        height: ResponsiveHelper.isMobile(context) ? 200 : 280,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            ResponsiveHelper.borderRadius(context, mobile: 24, tablet: 28),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            ResponsiveHelper.borderRadius(context, mobile: 24, tablet: 28),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Decorative overlays removed as per request
              // Banner image with full opacity
              if (url.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: const Color(0xFF6C5CE7)),
                  errorWidget: (_, __, ___) =>
                      Container(color: const Color(0xFF6C5CE7)),
                ),
              // Radial gradient overlay for depth removed as per request
              // Container(
              //   decoration: BoxDecoration(
              //     gradient: RadialGradient(
              //       center: Alignment.center,
              //       radius: 1.0,
              //       colors: [
              //         Colors.transparent,
              //         Colors.black.withOpacity(0.2),
              //         Colors.black.withOpacity(0.5),
              //       ],
              //       stops: const [0.0, 0.6, 1.0],
              //     ),
              //   ),
              // ),
              // Decorative border
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(
                    ResponsiveHelper.borderRadius(
                      context,
                      mobile: 24,
                      tablet: 28,
                    ),
                  ),
                ),
              ),
              // Content
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.isMobile(context) ? 20 : 32,
                    vertical: ResponsiveHelper.isMobile(context) ? 16 : 24,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Modern Badge with glow
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveHelper.isMobile(context)
                              ? 24
                              : 32,
                          vertical: ResponsiveHelper.isMobile(context)
                              ? 12
                              : 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                            BoxShadow(
                              color: const Color(0xFF6C5CE7).withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: const Color(0xFF6C5CE7),
                              size: ResponsiveHelper.isMobile(context)
                                  ? 24
                                  : 28,
                            ),
                            SizedBox(
                              width: ResponsiveHelper.spacing(
                                context,
                                10,
                              ),
                            ),
                            Text(
                              '✨ COMING SOON ✨',
                              style: ResponsiveHelper.textStyle(
                                context,
                                fontSize: ResponsiveHelper.fontSize(
                                  context,
                                  mobile: 14,
                                  tablet: 16,
                                ),
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF6C5CE7),
                                letterSpacing: 2,
                              ),
                            ),
                            Icon(
                              Icons.auto_awesome,
                              color: const Color(0xFF6C5CE7),
                              size: ResponsiveHelper.isMobile(context)
                                  ? 24
                                  : 28,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: ResponsiveHelper.spacing(
                          context,
                          16,
                        ),
                      ),
                      // Title with dramatic styling hidden as per request
                      // if (title.isNotEmpty)
                      //   Container(
                      //     padding: EdgeInsets.symmetric(
                      //       horizontal: ResponsiveHelper.isMobile(context)
                      //           ? 16
                      //           : 24,
                      //       vertical: ResponsiveHelper.isMobile(context)
                      //           ? 8
                      //           : 12,
                      //     ),
                      //     decoration: BoxDecoration(
                      //       color: Colors.black.withOpacity(0.4),
                      //       borderRadius: BorderRadius.circular(16),
                      //       border: Border.all(
                      //         color: Colors.white.withOpacity(0.4),
                      //         width: 2,
                      //       ),
                      //     ),
                      //     child: Text(
                      //       title.toUpperCase(),
                      //       textAlign: TextAlign.center,
                      //       style: ResponsiveHelper.textStyle(
                      //         context,
                      //         fontSize: ResponsiveHelper.fontSize(
                      //           context,
                      //           mobile: 20,
                      //           tablet: 26,
                      //         ),
                      //         fontWeight: FontWeight.bold,
                      //         color: Colors.white,
                      //         letterSpacing: 2,
                      //       ),
                      //     ),
                      //   ),
                      SizedBox(
                        height: ResponsiveHelper.spacing(
                          context,
                          20,
                        ),
                      ),
                      // Large Countdown Timer
                      Obx(
                        () => Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveHelper.isMobile(context)
                                ? 32
                                : 40,
                            vertical: ResponsiveHelper.isMobile(context)
                                ? 20
                                : 28,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.3),
                                Colors.white.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.6),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(
                                      ResponsiveHelper.isMobile(context)
                                          ? 8
                                          : 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.timer,
                                      color: Colors.white,
                                      size: ResponsiveHelper.isMobile(context)
                                          ? 24
                                          : 28,
                                    ),
                                  ),
                                  SizedBox(
                                    width: ResponsiveHelper.spacing(
                                      context,
                                      10,
                                    ),
                                  ),
                                  Text(
                                    'COUNTDOWN',
                                    style: ResponsiveHelper.textStyle(
                                      context,
                                      fontSize: ResponsiveHelper.fontSize(
                                        context,
                                        mobile: 13,
                                        tablet: 15,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: ResponsiveHelper.spacing(
                                  context,
                                  12,
                                ),
                              ),
                              Text(
                                ctrl.countdownText.value,
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: ResponsiveHelper.fontSize(
                                    context,
                                    mobile: 36,
                                    tablet: 48,
                                  ),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 4,
                                ),
                              ),
                              SizedBox(
                                height: ResponsiveHelper.spacing(
                                  context,
                                  8,
                                ),
                              ),
                              Text(
                                'Until Festival Begins',
                                style: ResponsiveHelper.textStyle(
                                  context,
                                  fontSize: ResponsiveHelper.fontSize(
                                    context,
                                    mobile: 11,
                                    tablet: 12,
                                  ),
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.9),
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveCountdown(
    BuildContext context,
    String bannerId,
    String? startsAt,
  ) {
    final countdownText = _countdowns[bannerId] ?? 'Loading...';

    if (countdownText == 'Ended' || countdownText == 'Loading...') {
      return const SizedBox.shrink();
    }

    // Determine if banner is upcoming or ongoing
    final isUpcoming =
        startsAt != null && DateTime.parse(startsAt).isAfter(DateTime.now());
    final labelText = isUpcoming ? 'Starts in ' : 'Ends in ';
    final iconData = isUpcoming ? Icons.schedule : Icons.timer_outlined;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveHelper.isMobile(context) ? 8 : 10,
        vertical: ResponsiveHelper.isMobile(context) ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            color: isUpcoming
                ? const Color(0xFF667EEA)
                : const Color(0xFF764BA2),
            size: ResponsiveHelper.isMobile(context) ? 10 : 12,
          ),
          SizedBox(width: ResponsiveHelper.spacing(context, 3)),
          Text(
            labelText,
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(
                context,
                mobile: 9,
                tablet: 10,
              ),
              fontWeight: FontWeight.w600,
              color: const Color(0xFF666666),
            ),
          ),
          SizedBox(width: ResponsiveHelper.spacing(context, 2)),
          Text(
            countdownText,
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(
                context,
                mobile: 10,
                tablet: 11,
              ),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0C0F10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCountdown(
    BuildContext context,
    Map<String, dynamic> countdown,
  ) {
    final days = countdown['days']?.toString() ?? '0';
    final hours = countdown['hours']?.toString() ?? '0';
    final minutes = countdown['minutes']?.toString() ?? '0';

    return Row(
      children: [
        _buildMiniTimeUnit(context, days, 'd'),
        SizedBox(width: 4),
        Text(':', style: TextStyle(color: Colors.white70, fontSize: 12)),
        SizedBox(width: 4),
        _buildMiniTimeUnit(context, hours, 'h'),
        SizedBox(width: 4),
        Text(':', style: TextStyle(color: Colors.white70, fontSize: 12)),
        SizedBox(width: 4),
        _buildMiniTimeUnit(context, minutes, 'm'),
      ],
    );
  }

  Widget _buildTimeUnit(BuildContext context, String value, String unit) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: ResponsiveHelper.textStyle(
            context,
            fontSize: ResponsiveHelper.fontSize(
              context,
              mobile: 18,
              tablet: 22,
            ),
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(width: 2),
        Text(
          unit,
          style: TextStyle(
            fontSize: ResponsiveHelper.fontSize(
              context,
              mobile: 10,
              tablet: 11,
            ),
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniTimeUnit(BuildContext context, String value, String unit) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: ResponsiveHelper.fontSize(
              context,
              mobile: 14,
              tablet: 16,
            ),
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: ResponsiveHelper.fontSize(
              context,
              mobile: 9,
              tablet: 10,
            ),
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
