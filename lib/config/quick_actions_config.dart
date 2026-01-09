import 'package:flutter/material.dart';
import 'package:fruitsofspirit/routes/routes.dart';

/// Quick Actions Configuration
/// Defines icons, labels, and routes for quick action buttons
class QuickActionsConfig {
  /// Get all quick actions with their configuration - Theme Colors
  static List<QuickAction> getQuickActions() {
    // App theme colors: #8B4513 (brown), #5F4628 (dark brown)
    return [
      QuickAction(
        id: 'prayer',
        icon: Icons.volunteer_activism, // Material Icons praying hands (fallback)
        iconColor: const Color(0xFF8B4513), // Theme brown
        backgroundColor: const Color(0xFF8B4513).withOpacity(0.08), // Light brown background
        label: 'Prayer Request',
        route: Routes.CREATE_PRAYER,
        description: 'Share your prayer requests',
        imagePath: 'assets/praying.png', // PNG image from assets
      ),
      QuickAction(
        id: 'bloggers',
        icon: Icons.auto_stories, // Fallback icon
        iconColor: const Color(0xFF5F4628), // Dark brown
        backgroundColor: const Color(0xFF5F4628).withOpacity(0.08), // Light dark brown background
        label: 'Bloggers',
        route: Routes.BLOGGER_ZONE,
        description: 'Read and share blogs',
        imagePath: 'assets/blogger.png', // PNG image from assets
      ),
      QuickAction(
        id: 'groups',
        icon: Icons.groups, // Fallback icon
        iconColor: const Color(0xFF8B4513), // Theme brown
        backgroundColor: const Color(0xFF8B4513).withOpacity(0.1), // Slightly darker brown background
        label: 'Groups',
        route: Routes.GROUPS,
        description: 'Join or create groups',
        imagePath: 'assets/group.png', // PNG image from assets
      ),
      QuickAction(
        id: 'fruits',
        icon: Icons.spa,
        iconColor: const Color(0xFF5F4628), // Dark brown
        backgroundColor: const Color(0xFF5F4628).withOpacity(0.1), // Light dark brown background
        label: 'Fruits of Spirit',
        route: Routes.FRUITS,
        description: 'Explore fruits of the spirit',
        imagePath: 'assets/healthy-food.png', // PNG image from assets
      ),
    ];
  }

  /// Get quick action by ID
  static QuickAction? getQuickActionById(String id) {
    return getQuickActions().firstWhere(
      (action) => action.id == id,
      orElse: () => getQuickActions().first,
    );
  }
}

/// Quick Action Model
class QuickAction {
  final String id;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String label;
  final String route;
  final String description;
  final String? imagePath; // Optional image path for PNG/GIF assets

  QuickAction({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.label,
    required this.route,
    required this.description,
    this.imagePath, // Optional - if provided, will use image instead of icon
  });

  /// Convert to Map for JSON serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'icon': icon.codePoint,
      'iconColor': iconColor.value,
      'backgroundColor': backgroundColor.value,
      'label': label,
      'route': route,
      'description': description,
    };
  }

  /// Create from Map (for JSON deserialization)
  factory QuickAction.fromMap(Map<String, dynamic> map) {
    return QuickAction(
      id: map['id'] as String,
      icon: IconData(map['icon'] as int, fontFamily: 'MaterialIcons'),
      iconColor: Color(map['iconColor'] as int),
      backgroundColor: Color(map['backgroundColor'] as int),
      label: map['label'] as String,
      route: map['route'] as String,
      description: map['description'] as String,
    );
  }
}

