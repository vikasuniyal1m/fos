import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fruitsofspirit/controllers/prayers_controller.dart';
import 'package:fruitsofspirit/controllers/groups_controller.dart';
import 'package:fruitsofspirit/utils/responsive_helper.dart';
import 'package:fruitsofspirit/services/user_storage.dart';
import 'package:fruitsofspirit/services/users_service.dart';
import 'package:fruitsofspirit/widgets/cached_image.dart';
import 'package:fruitsofspirit/services/prayer_types_service.dart';

import 'package:fruitsofspirit/routes/app_pages.dart';
import 'package:fruitsofspirit/utils/app_theme.dart';
import '../controllers/main_dashboard_controller.dart';
import '../services/terms_service.dart';
import '../services/content_moderation_service.dart';
import '../services/user_storage.dart' as us;
import 'terms_acceptance_screen.dart';

/// Create Prayer Request Screen
/// Matches the "New Prayer" UI design from the image
class CreatePrayerScreen extends StatefulWidget {
  const CreatePrayerScreen({Key? key}) : super(key: key);

  @override
  State<CreatePrayerScreen> createState() => _CreatePrayerScreenState();
}

class _CreatePrayerScreenState extends State<CreatePrayerScreen> {
  late final PrayersController prayersController;
  late final GroupsController groupsController;
  
  final TextEditingController contentController = TextEditingController();
  final TextEditingController customPrayerTypeController = TextEditingController();

  // State variables
  String prayerFor = 'Me'; // 'Me', 'Someone else', 'Group', 'All'
  String selectedPrayerType = 'Healing'; // Single selection only
  bool allowEncouragement = true;
  bool isAnonymous = true;
  List<int> sharedWithUserIds = [];
  
  // Custom category for 'Others' option
  final TextEditingController customCategoryController = TextEditingController();
  bool isCustomCategory = false;
  
  // Tagging variables
  int? taggedUserId; // For "Someone else"
  int? taggedGroupId; // For "Group"
  Map<String, dynamic>? selectedUser;
  Map<String, dynamic>? selectedGroup;
  
  // User search
  final TextEditingController userSearchController = TextEditingController();
  List<Map<String, dynamic>> searchUsers = [];
  bool isSearchingUsers = false;
  bool _isSubmitting = false; // Loading state for prayer submission
  String? _moderationMessage; // Real-time moderation message
  
  // Available prayer types - will be loaded from backend
  // Available prayer types - will be loaded from backend
  List<String> prayerTypes = [
    'Healing',
    'Peace & Anxiety',
    'Work & Provision',
    'Relationships',
    'Guidance',
    'Strength',
    'Protection',
    'Wisdom',
    'Forgiveness',
    'Financial',
    'Family',
    'Addiction',
    'Grief',
    'Faith',
    'Thanksgiving',
    'Deliverance',
    'other'
  ];
  bool isLoadingPrayerTypes = false;

  @override
  void initState() {
    super.initState();

    // Safely find or initialize PrayersController
    try {
      prayersController = Get.find<PrayersController>();
    } catch (e) {
      prayersController = Get.put(PrayersController());
    }

    // Safely find or initialize GroupsController
    try {
      groupsController = Get.find<GroupsController>();
    } catch (e) {
      groupsController = Get.put(GroupsController());
    }

    _loadGroupMembers();
    _loadPrayerTypes();

    // Add real-time moderation check
    contentController.addListener(_checkModeration);
  }

  Future<void> _loadPrayerTypes() async {
    setState(() {
      isLoadingPrayerTypes = true;
    });

    try {
      final types = await PrayerTypesService.getPrayerTypes();
      if (types.isNotEmpty) {
        setState(() {
          prayerTypes = types;
        });
      }
    } catch (e) {
      print('Error loading prayer types: $e');
      // Keep default types if loading fails
    } finally {
      setState(() {
        isLoadingPrayerTypes = false;
      });
    }
  }

  void _checkModeration() {
    final text = contentController.text;
    if (text.isEmpty) {
      if (_moderationMessage != null) {
        setState(() => _moderationMessage = null);
      }
      return;
    }

    final result = ContentModerationService.checkContent(text);
    if (!result['isClean']) {
      if (_moderationMessage != result['message']) {
        setState(() => _moderationMessage = result['message']);
      }
    } else {
      if (_moderationMessage != null) {
        setState(() => _moderationMessage = null);
      }
    }
  }
  
  Future<void> _loadGroupMembers() async {
    try {
      await groupsController.loadUserGroups();
      if (groupsController.userGroups.isNotEmpty) {
        // Load members for the first group
        await groupsController.loadGroupMembers(groupsController.userGroups[0]['id']);
      }
    } catch (e) {
      print('Error loading groups: $e');
    }
  }
  
  @override
  void dispose() {
    contentController.removeListener(_checkModeration);
    contentController.dispose();
    userSearchController.dispose();
    customPrayerTypeController.dispose();
    super.dispose();
  }
  
  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchUsers = [];
        isSearchingUsers = false;
      });
      return;
    }
    
    setState(() {
      isSearchingUsers = true;
    });
    
    try {
      final users = await UsersService.getUsers(search: query, limit: 20);
      setState(() {
        searchUsers = users;
        isSearchingUsers = false;
      });
    } catch (e) {
      setState(() {
        searchUsers = [];
        isSearchingUsers = false;
      });
    }
  }
  
  void _selectPrayerType(String type) {
                    setState(() {
      selectedPrayerType = type;
    });
  }
  
  void _toggleShareWith(int userId) {
    setState(() {
      if (sharedWithUserIds.contains(userId)) {
        sharedWithUserIds.remove(userId);
      } else {
        sharedWithUserIds.add(userId);
      }
    });
  }

  void _showCustomSnackbar(String title, String message, {bool isError = false, bool isModeration = false}) {
    if (!mounted) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isModeration ? Icons.security_rounded : (isError ? Icons.error_outline : Icons.check_circle_outline),
                    color: isModeration ? const Color(0xFFC79211) : Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          backgroundColor: isModeration 
              ? const Color(0xFF5D4037) 
              : (isError ? Colors.red.withOpacity(0.9) : AppTheme.iconscolor),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 16)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: Duration(seconds: isModeration ? 5 : 3),
          action: isModeration ? SnackBarAction(
            label: 'VIEW TERMS',
            textColor: const Color(0xFFC79211),
            onPressed: () => Get.toNamed(Routes.TERMS),
          ) : null,
        ),
      );
    });
  }

  Future<void> _submitPrayer() async {
    if (_isSubmitting) return; // Prevent multiple submissions

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    // Check for terms acceptance
    final hasAcceptedFactors = await TermsService.hasAcceptedTerms();
    if (!hasAcceptedFactors) {
      Get.to(() => TermsAcceptanceScreen(
        onAccepted: () {
          if (mounted) {
            Navigator.of(context).pop(); // Use standard Navigator to avoid GetX snackbar crash
            _submitPrayer(); // Retry submission
          }
        },
      ));
      return;
    }
    
    if (contentController.text.trim().isEmpty) {
      _showCustomSnackbar('Error', 'Please enter your prayer request', isError: true);
      return;
    }

    // Handle custom prayer type
    String category = selectedPrayerType;
    if (selectedPrayerType == 'other') {
      if (customPrayerTypeController.text.trim().isEmpty) {
        _showCustomSnackbar('Error', 'Please enter custom prayer type', isError: true);
        return;
      }
      category = customPrayerTypeController.text.trim();

      // Save custom prayer type to backend
      try {
        final userId = await UserStorage.getUserId();
        if (userId != null) {
          await PrayerTypesService.addPrayerType(typeName: category, userId: userId);
        }
      } catch (e) {
        print('Error saving custom prayer type: $e');
        // Continue with submission even if saving type fails
      }
    }
    
    // Validate tagging
    if (prayerFor == 'Someone else' && taggedUserId == null) {
      _showCustomSnackbar('Error', 'Please select a user', isError: true);
      return;
    }
    
    if (prayerFor == 'Group' && taggedGroupId == null) {
      _showCustomSnackbar('Error', 'Please select a group', isError: true);
      return;
    }
    
    // Show loading
    setState(() {
      _isSubmitting = true;
    });
    
    final success = await prayersController.createPrayer(
      category: category,
      content: contentController.text.trim(),
      prayerFor: prayerFor,
      allowEncouragement: allowEncouragement,
      isAnonymous: isAnonymous,
      sharedWithUserIds: sharedWithUserIds,
      taggedUserId: taggedUserId,
      taggedGroupId: taggedGroupId,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
    }

    if (success) {
      // Show success message with professional text
      _showCustomSnackbar(
        'Request Submitted',
        'Your prayer request has been submitted successfully.'
      );

      // Navigate to prayer requests screen and refresh
      // Reset filter to show all prayers
      prayersController.filterUserId.value = 0;
      prayersController.selectedCategory.value = '';

             // Force refresh (fire and forget)
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
            if (Get.isRegistered<PrayersController>()) {
                Get.find<PrayersController>().loadPrayers(refresh: true);
            }
        } catch (e) {
            print('Error refreshing prayers: $e');
        }
      });
        
          // Update Dashboard Tab Logic if available
      if (Get.isRegistered<MainDashboardController>()) {
        try {
          Get.find<MainDashboardController>().changeIndex(2); // Switch to Prayer Requests tab
        } catch (e) {
          print('Error changing dashboard index: $e');
        }
      }
      
      // Wait briefly for snackbar
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // STRONG NAVIGATION: Clear stack until Dashboard
      // This is the most reliable way to "go back" to a main tab
      Get.offNamedUntil(Routes.DASHBOARD, (route) => false);
    } else {
      // Show error message
      if (mounted) {
        final errorMsg = prayersController.message.value;
        final isModeration = errorMsg.contains('community guidelines') || 
                            errorMsg.contains('inappropriate content');
        
        _showCustomSnackbar(
          isModeration ? 'Community Standard' : 'Notice',
          errorMsg.isNotEmpty 
              ? errorMsg 
              : 'Action could not be completed. Please try again.',
          isError: !isModeration,
          isModeration: isModeration,
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.themeColor, // Light beige background - matches home page
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          ResponsiveHelper.appBarHeight(context),
        ),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Container(
            margin: EdgeInsets.all(ResponsiveHelper.spacing(context, 8)),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: AppTheme.iconscolor,
                size: ResponsiveHelper.iconSize(context, mobile: 24, tablet: 28, desktop: 32),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.spacing(context, 10),
                vertical: ResponsiveHelper.spacing(context, 6),
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.iconscolor.withOpacity(0.1),
                    AppTheme.iconscolor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(
                  ResponsiveHelper.borderRadius(context, mobile: 20),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite_rounded,
                    size: ResponsiveHelper.iconSize(context, mobile: 20),
                    color: AppTheme.iconscolor,
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 6)),
                  Text(
                    'New Prayer',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 18),
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            Spacer(),
            // Dynamic prayer type badge
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.spacing(context, 10),
                vertical: ResponsiveHelper.spacing(context, 6),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  ResponsiveHelper.borderRadius(context, mobile: 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department_rounded, color: AppTheme.iconscolor, size: ResponsiveHelper.iconSize(context, mobile: 16)),
                  SizedBox(width: ResponsiveHelper.spacing(context, 4)),
                  Text(
                    selectedPrayerType,
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: ResponsiveHelper.fontSize(context, mobile: 12),
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.grey[300]!,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        ),
      ),
      body: SingleChildScrollView(
        padding: ResponsiveHelper.padding(context, all: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Who is this for ?? Section
            _buildSectionTitle('Who is this for ??'),
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            // First row: Me, Someone else
            Row(
              children: [
                Expanded(
                  child: _buildSelectionButton(
                    'Me',
                    prayerFor == 'Me',
                    onTap: () => setState(() {
                      prayerFor = 'Me';
                      taggedUserId = null;
                      taggedGroupId = null;
                      selectedUser = null;
                      selectedGroup = null;
                    }),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                Expanded(
                  child: _buildSelectionButton(
                    'Someone else',
                    prayerFor == 'Someone else',
                    onTap: () => setState(() {
                      prayerFor = 'Someone else';
                      taggedGroupId = null;
                      selectedGroup = null;
                    }),
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            // Second row: Group, All
            Row(
              children: [
                Expanded(
                  child: _buildSelectionButton(
                    'Group',
                    prayerFor == 'Group',
                    onTap: () => setState(() {
                      prayerFor = 'Group';
                      taggedUserId = null;
                      selectedUser = null;
                      userSearchController.clear();
                      searchUsers = [];
                    }),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                Expanded(
                  child: _buildSelectionButton(
                    'All',
                    prayerFor == 'All',
                    onTap: () => setState(() {
                      prayerFor = 'All';
                      taggedUserId = null;
                      taggedGroupId = null;
                      selectedUser = null;
                      selectedGroup = null;
                      userSearchController.clear();
                      searchUsers = [];
                    }),
                  ),
                ),
              ],
            ),
            
            // Show user/group selection based on prayerFor
            if (prayerFor == 'Someone else') ...[
              SizedBox(height: ResponsiveHelper.spacing(context, 16)),
              _buildUserSelectionSection(),
            ],
            if (prayerFor == 'Group') ...[
              SizedBox(height: ResponsiveHelper.spacing(context, 16)),
              _buildGroupSelectionSection(),
            ],
            
              SizedBox(height: ResponsiveHelper.spacing(context, 24)),
            
            // Types of prayer Section
            _buildSectionTitle('Types of prayer'),
            const SizedBox(height: 6),
            Text(
              'Select one or more to help others pray specifically',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: prayerTypes.map((type) {
                final isSelected = selectedPrayerType == type;
                return _buildPrayerTypeButton(type, isSelected);
              }).toList(),
            ),
            // Custom prayer type field when "other" is selected
            if (selectedPrayerType == 'other')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: ResponsiveHelper.spacing(context, 12)),
                  Text(
                    'Add Custom Prayer Type',
                    style: ResponsiveHelper.textStyle(
                      context,
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 8)),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: customPrayerTypeController,
                      decoration: InputDecoration(
                        hintText: 'Enter custom prayer type...',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      style: ResponsiveHelper.textStyle(
                        context,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 24)),
            
            // Details Section
            _buildSectionTitle('Details'),
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: contentController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: 'Write your prayer request .........',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: ResponsiveHelper.textStyle(
                  context,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ),
            if (_moderationMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.security_rounded, color: Color(0xFFC79211), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _moderationMessage!,
                        style: const TextStyle(
                          color: Color(0xFF5D4037),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(context, 24)),
            
            // Toggle Options
            Container(
              padding: ResponsiveHelper.padding(context, all: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
              ),
              child: Column(
                children: [
                  _buildToggleOption(
                    'Allow encouragement',
                    'Group members can react with emojis',
                    allowEncouragement,
                    (value) => setState(() => allowEncouragement = value),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(context, 16)),
                  _buildToggleOption(
                    'Anonymous',
                    'Hide your name from the post',
                    isAnonymous,
                    (value) => setState(() => isAnonymous = value),
                  ),
                ],
              ),
            ),
              SizedBox(height: ResponsiveHelper.spacing(context, 24)),
            
            // Share with Section
            _buildSectionTitle('Share with'),
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            Obx(() {
              if (groupsController.groupMembers.isEmpty) {
                return Container(
                  padding: ResponsiveHelper.padding(context, all: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ResponsiveHelper.borderRadius(context, mobile: 12)),
                  ),
                  child: Text(
                    'No group members available',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                );
              }
              
              return SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: groupsController.groupMembers.length,
                  itemBuilder: (context, index) {
                    final member = groupsController.groupMembers[index];
                    final userId = member['user_id'] ?? member['id'];
                    final userName = member['name'] ?? 'User';
                    final isSelected = sharedWithUserIds.contains(userId);
                    
                    return GestureDetector(
                      onTap: () => _toggleShareWith(userId),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: isSelected
                                      ? AppTheme.iconscolor.withOpacity(0.3)
                                      : Colors.grey[200],
                                  child: CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.white,
                                    child: CachedImage(
                                      imageUrl: member['profile_photo'] ?? '',
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      errorWidget: Icon(
                                        Icons.person,
                                        size: 30,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.iconscolor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 4),
                            SizedBox(
                              width: 60,
                              child: Text(
                                userName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
            const SizedBox(height: 32),
            
            // Bottom Action Buttons
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Cancel',
                    Colors.white,
                    Colors.black,
                    true,
                    () => Navigator.of(context).pop(),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                Expanded(
                  child: _buildActionButton(
                    'Submit Request',
                    AppTheme.iconscolor,
                    Colors.white,
                    false,
                    _submitPrayer,
                    isLoading: _isSubmitting,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: ResponsiveHelper.textStyle(
        context,
        fontSize: ResponsiveHelper.fontSize(context, mobile: 16),
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }
  
  Widget _buildSelectionButton(String text, bool isSelected, {required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.iconscolor
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.iconscolor
                  : Colors.grey.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.iconscolor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              text,
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPrayerTypeButton(String type, bool isSelected) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectPrayerType(type),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.iconscolor
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.iconscolor
                  : Colors.grey.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.iconscolor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            type,
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildToggleOption(String title, String description, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.iconscolor,
          activeTrackColor: AppTheme.iconscolor.withOpacity(0.5),
        ),
      ],
    );
  }
  
  Widget _buildActionButton(
    String text,
    Color backgroundColor,
    Color textColor,
    bool hasBorder,
    VoidCallback onTap, {
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isLoading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isLoading ? Colors.grey : backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: hasBorder
                ? Border.all(
                    color: AppTheme.iconscolor,
                    width: 1,
                  )
                : null,
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                : Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildUserSelectionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select User',
            style: ResponsiveHelper.textStyle(
              context,
              fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          // Search field
          TextField(
            controller: userSearchController,
            decoration: InputDecoration(
              hintText: 'Search by name, email...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.iconscolor, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: TextStyle(fontSize: 14, color: Colors.black87),
            onChanged: (value) {
              if (value.length >= 2) {
                _searchUsers(value);
              } else {
                setState(() {
                  searchUsers = [];
                });
              }
            },
          ),
          const SizedBox(height: 12),
          // Selected user display
          if (selectedUser != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.iconscolor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.iconscolor,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: selectedUser!['profile_photo'] != null
                        ? NetworkImage(
                            (selectedUser!['profile_photo'] as String).startsWith('http://') || 
                            (selectedUser!['profile_photo'] as String).startsWith('https://')
                              ? selectedUser!['profile_photo'] as String
                              : 'http://admin.fosmessenger.com/${selectedUser!['profile_photo']}'
                          )
                        : null,
                    child: selectedUser!['profile_photo'] == null
                        ? Icon(Icons.person, size: 20, color: Colors.grey[600])
                        : null,
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedUser!['name'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (selectedUser!['email'] != null)
                          Text(
                            selectedUser!['email'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: Colors.grey[600]),
                    onPressed: () {
                      setState(() {
                        selectedUser = null;
                        taggedUserId = null;
                        userSearchController.clear();
                        searchUsers = [];
                      });
                    },
                  ),
                ],
              ),
            ),
          // Search results
          if (userSearchController.text.isNotEmpty && searchUsers.isNotEmpty) ...[
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: searchUsers.length,
                itemBuilder: (context, index) {
                  final user = searchUsers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: user['profile_photo'] != null
                          ? NetworkImage(
                              (user['profile_photo'] as String).startsWith('http://') || 
                              (user['profile_photo'] as String).startsWith('https://')
                                ? user['profile_photo'] as String
                                : 'http://admin.fosmessenger.com/${user['profile_photo']}'
                            )
                          : null,
                      child: user['profile_photo'] == null
                          ? Icon(Icons.person, size: 20, color: Colors.grey[600])
                          : null,
                    ),
                    title: Text(
                      user['name'] ?? 'Unknown',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    subtitle: user['email'] != null
                        ? Text(
                            user['email'],
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        selectedUser = user;
                        taggedUserId = user['id'] as int;
                        userSearchController.clear();
                        searchUsers = [];
                      });
                    },
                  );
                },
              ),
            ),
          ],
          if (isSearchingUsers)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
  
  Widget _buildGroupSelectionSection() {
    return Obx(() {
      if (groupsController.userGroups.isEmpty) {
        return Container(
          padding: ResponsiveHelper.padding(context, all: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Text(
            'You are not a member of any groups yet',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        );
      }
      
      return Container(
        padding: ResponsiveHelper.padding(context, all: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Group',
              style: ResponsiveHelper.textStyle(
                context,
                fontSize: ResponsiveHelper.fontSize(context, mobile: 14),
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(context, 12)),
            // Selected group display
            if (selectedGroup != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.iconscolor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.iconscolor,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: selectedGroup!['image'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedImage(
                                imageUrl: 'http://admin.fosmessenger.com/${selectedGroup!['image']}',
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(Icons.group, size: 24, color: Colors.grey[600]),
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(context, 12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedGroup!['name'] ?? 'Unknown Group',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          if (selectedGroup!['member_count'] != null)
                            Text(
                              '${selectedGroup!['member_count']} members',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: Colors.grey[600]),
                      onPressed: () {
                        setState(() {
                          selectedGroup = null;
                          taggedGroupId = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            // Group list
            if (selectedGroup == null)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: groupsController.userGroups.length,
                  itemBuilder: (context, index) {
                    final group = groupsController.userGroups[index];
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: group['image'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedImage(
                                  imageUrl: 'http://admin.fosmessenger.com/${group['image']}',
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(Icons.group, size: 24, color: Colors.grey[600]),
                      ),
                      title: Text(
                        group['name'] ?? 'Unknown Group',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      subtitle: group['member_count'] != null
                          ? Text(
                              '${group['member_count']} members',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          selectedGroup = group;
                          taggedGroupId = group['id'] as int;
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      );
    });
  }
}
