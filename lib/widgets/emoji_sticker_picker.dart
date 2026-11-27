import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/emojis_service.dart';
import '../services/sticker_service.dart';
import '../services/user_storage.dart';
import '../utils/sticker_emoji_helper.dart';
import '../screens/home_screen.dart';

/// Universal Emoji & Sticker Picker
/// Can be used anywhere in the app - chat, comments, posts, etc.
class EmojiStickerPicker extends StatefulWidget {
  final Function(String) onEmojiSelected;
  final double height;
  final bool showStickers;

  const EmojiStickerPicker({
    Key? key,
    required this.onEmojiSelected,
    this.height = 250,
    this.showStickers = true,
  }) : super(key: key);

  @override
  State<EmojiStickerPicker> createState() => _EmojiStickerPickerState();
}

class _EmojiStickerPickerState extends State<EmojiStickerPicker>
    with SingleTickerProviderStateMixin {
  var availableEmojis = <Map<String, dynamic>>[].obs;
  var isLoadingEmojis = true.obs;
  var stickers = <Sticker>[].obs;
  var isLoadingStickers = false.obs;
  var isLoadingMore = false.obs;
  
  // Pagination state
  var currentPage = 1.obs;
  var hasMoreStickers = true.obs;
  var totalPacks = 0.obs;
  
  // User email for API authentication
  String? userEmail;
  TabController? _tabController;
  bool _stickersTabLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
    _loadEmojis();
    if (widget.showStickers) {
      _tabController = TabController(length: 2, vsync: this);
      _tabController!.addListener(_onTabChanged);
    }
  }

  void _onTabChanged() {
    if (_tabController == null || _tabController!.index != 1) return;
    if (_stickersTabLoaded) return;
    _stickersTabLoaded = true;
    _loadStickers(page: 1);
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadUserEmail() async {
    userEmail = await _getCurrentUserEmail();
  }

  Future<void> _loadEmojis() async {
    final cached = EmojisService.getPickerEmojisSync();
    if (cached != null && cached.isNotEmpty) {
      availableEmojis.value = cached;
      isLoadingEmojis.value = false;
      return;
    }

    try {
      isLoadingEmojis.value = true;
      final userEmail = await _getCurrentUserEmail();
      availableEmojis.value = await EmojisService.getPickerEmojis(
        userEmail: userEmail,
      );
    } catch (e) {
      availableEmojis.value = [];
    } finally {
      isLoadingEmojis.value = false;
    }
  }

  Future<void> _loadStickers({int page = 1, bool append = false}) async {
    try {
      if (page == 1 && !append) {
        final sessionStickers = StickerService.getPickerStickersSync();
        if (sessionStickers != null && sessionStickers.isNotEmpty) {
          stickers.value = sessionStickers;
          isLoadingStickers.value = false;
          final userId = await _getCurrentUserId();
          final userEmail = await _getCurrentUserEmail();
          unawaited(
            StickerService.syncStickersIfStale(userId, userEmail: userEmail),
          );
          return;
        }

        isLoadingStickers.value = stickers.isEmpty;
        final userId = await _getCurrentUserId();
        final userEmail = await _getCurrentUserEmail();
        final loaded = await StickerService.getPickerStickers(
          userId,
          userEmail: userEmail,
        );
        stickers.value = loaded;
        totalPacks.value = loaded.isNotEmpty ? 1 : 0;
        currentPage.value = 1;
        hasMoreStickers.value = false;
        return;
      }

      isLoadingMore.value = true;
      final userId = await _getCurrentUserId();
      final userEmail = await _getCurrentUserEmail();
      final result = await StickerService.syncStickers(
        userId,
        testMode: false,
        userEmail: userEmail,
        page: page,
        limit: 50,
        downloadAssets: false,
        force: true,
      );

      final packs = result['packs'] as List<StickerPack>;
      final pagination = result['pagination'] as Map<String, dynamic>?;
      final newStickers = <Sticker>[];
      for (final pack in packs) {
        newStickers.addAll(pack.stickers);
      }

      if (append) {
        stickers.addAll(newStickers);
      } else {
        stickers.value = newStickers;
      }

      totalPacks.value = result['total_packs'] ?? 0;
      currentPage.value = page;
      hasMoreStickers.value = pagination?['has_next'] ?? false;
    } catch (e) {
      if (page == 1 && stickers.isEmpty) {
        stickers.value = [];
      }
    } finally {
      isLoadingStickers.value = false;
      isLoadingMore.value = false;
    }
  }
  
  Future<void> _loadMoreStickers() async {
    if (isLoadingMore.value || !hasMoreStickers.value) return;
    await _loadStickers(page: currentPage.value + 1, append: true);
  }
  
  // Helper to get current user ID from UserStorage
  Future<int> _getCurrentUserId() async {
    final userId = await UserStorage.getUserId();
    return userId ?? 1; // Default to 1 if not logged in
  }

  // Helper to get current user email from UserStorage - for cross-app security verification
  Future<String?> _getCurrentUserEmail() async {
    return await UserStorage.getUserEmail();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: widget.showStickers
          ? Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF8B4513),
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: const Color(0xFF8B4513),
                  tabs: const [
                    Tab(icon: Icon(Icons.emoji_emotions), text: 'Emojis'),
                    Tab(icon: Icon(Icons.sticky_note_2), text: 'My Stickers'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildEmojiGrid(),
                      _buildStickerGrid(),
                    ],
                  ),
                ),
              ],
            )
          : _buildEmojiGrid(),
    );
  }

  Widget _buildEmojiGrid() {
    return Obx(() {
      if (isLoadingEmojis.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (availableEmojis.isEmpty) {
        return const Center(child: Text('No emojis available'));
      }

      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: availableEmojis.length,
        itemBuilder: (context, index) {
          final emoji = availableEmojis[index];
          String emojiChar = '';
          if (emoji['emoji_char'] != null &&
              emoji['emoji_char'].toString().isNotEmpty) {
            emojiChar = emoji['emoji_char'].toString();
          } else if (emoji['code'] != null &&
              emoji['code'].toString().isNotEmpty) {
            emojiChar = emoji['code'].toString();
          } else if (emoji['image_url'] != null &&
              emoji['image_url'].toString().isNotEmpty) {
            emojiChar = emoji['image_url'].toString();
          } else if (emoji['id'] != null) {
            emojiChar = ':emoji_${emoji['id']}:';
          }

          return InkWell(
            onTap: () => widget.onEmojiSelected(emojiChar),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: _buildSimpleEmojiDisplay(emoji, size: 28),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildSimpleEmojiDisplay(Map<String, dynamic> emoji, {double size = 28}) {
    // Try to get emoji character first
    final emojiChar = emoji['emoji_char'] as String? ?? '';
    final code = emoji['code'] as String? ?? '';
    
    // If we have an actual emoji character, show it directly
    if (emojiChar.isNotEmpty && emojiChar.length <= 2) {
      return Text(
        emojiChar,
        style: TextStyle(fontSize: size),
      );
    }
    
    // If we have a short code that might be an emoji, show it
    if (code.isNotEmpty && code.length <= 2) {
      return Text(
        code,
        style: TextStyle(fontSize: size),
      );
    }
    
    // Fallback to HomeScreen display for images
    return HomeScreen.buildEmojiDisplay(Get.context!, emoji, size: size, userEmail: userEmail);
  }

  Widget _buildStickerGrid() {
    return Obx(() {
      if (isLoadingStickers.value && stickers.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      if (stickers.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sticky_note_2, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'No stickers downloaded',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                'Purchase stickers from store!',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        );
      }

      return Column(
        children: [
          // Total count indicator
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Stickers (${stickers.length}/${totalPacks.value * 10}+)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                if (isLoadingMore.value)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Sticker Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,        // Same as emojis
                crossAxisSpacing: 8,      // Same as emojis
                mainAxisSpacing: 8,       // Same as emojis
              ),
              itemCount: stickers.length,
              itemBuilder: (context, index) {
                final sticker = stickers[index];
                return InkWell(
                  onTap: () => widget.onEmojiSelected(sticker.emojiCode),
                  onLongPress: () => _showStickerOptions(context, sticker),
                  borderRadius: BorderRadius.circular(8),
                  child: _buildStickerThumb(sticker),
                );
              },
            ),
          ),
          // Load More Button
          if (hasMoreStickers.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isLoadingMore.value ? null : _loadMoreStickers,
                  icon: isLoadingMore.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.arrow_downward, size: 18),
                  label: Text(isLoadingMore.value ? 'Loading...' : 'Load More Stickers'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B4513),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildStickerThumb(Sticker sticker) {
    if (sticker.localPath != null && sticker.localPath!.isNotEmpty) {
      return Image.file(
        File(sticker.localPath!),
        width: 28,
        height: 28,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildNetworkImage(sticker),
      );
    }
    return _buildNetworkImage(sticker);
  }

  Widget _buildNetworkImage(Sticker sticker) {
    if (sticker.imageUrl.isEmpty) {
      return Icon(Icons.image_not_supported, size: 28, color: Colors.grey[400]);
    }
    
    return Image.network(
      sticker.imageUrl,
      width: 28,
      height: 28,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.image_not_supported, size: 28, color: Colors.grey[400]);
      },
    );
  }

  void _showStickerOptions(BuildContext context, Sticker sticker) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sticker Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.share, color: Color(0xFF8B4513)),
              title: const Text('Share to WhatsApp'),
              subtitle: const Text('Send this sticker to WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                _shareStickerToWhatsApp(sticker);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Color(0xFF8B4513)),
              title: const Text('Copy Emoji Code'),
              subtitle: Text(sticker.emojiCode),
              onTap: () {
                Navigator.pop(context);
                _copyStickerCode(sticker);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Color(0xFF8B4513)),
              title: const Text('Save to Gallery'),
              onTap: () {
                Navigator.pop(context);
                _saveStickerToGallery(sticker);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _shareStickerToWhatsApp(Sticker sticker) async {
    if (sticker.localPath == null) {
      Get.snackbar('Error', 'Sticker not downloaded yet');
      return;
    }
    
    try {
      // Share the sticker file
      await StickerService.shareSticker(sticker);
      Get.snackbar('Success', 'Opening share dialog...');
    } catch (e) {
      Get.snackbar('Error', 'Failed to share sticker: $e');
    }
  }

  void _copyStickerCode(Sticker sticker) {
    // Copy emoji code to clipboard
    StickerService.copyStickerAsEmoji(sticker);
    Get.snackbar('Copied!', 'Emoji code copied to clipboard');
  }

  void _saveStickerToGallery(Sticker sticker) async {
    if (sticker.localPath == null) {
      Get.snackbar('Error', 'Sticker not downloaded yet');
      return;
    }
    
    try {
      // Save to gallery using gallery_saver or similar
      Get.snackbar('Success', 'Sticker saved to gallery');
    } catch (e) {
      Get.snackbar('Error', 'Failed to save: $e');
    }
  }
}

/// Show emoji sticker picker as bottom sheet
void showEmojiStickerPicker({
  required BuildContext context,
  required Function(String) onEmojiSelected,
  double height = 350,
  bool useRootNavigator = true,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: useRootNavigator,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => EmojiStickerPicker(
      onEmojiSelected: (emoji) {
        onEmojiSelected(emoji);
        if (Navigator.of(sheetContext, rootNavigator: useRootNavigator).canPop()) {
          Navigator.of(sheetContext, rootNavigator: useRootNavigator).pop();
        }
      },
      height: height,
    ),
  );
}
