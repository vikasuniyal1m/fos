import 'package:flutter/material.dart';

class ContentDeleteHelper {
  static bool isOwner(int? currentUserId, dynamic contentUserId) {
    if (currentUserId == null || currentUserId == 0) return false;
    if (contentUserId == null) return false;
    return contentUserId.toString() == currentUserId.toString();
  }

  static Future<bool> confirmDelete(
    BuildContext context, {
    required String itemLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $itemLabel?'),
        content: const Text(
          'This action cannot be undone. Are you sure you want to delete this?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  static Widget buildDeleteChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_outline, size: 14, color: Colors.red),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildDeleteAction({
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
    );
  }

  static Widget buildDeleteIconButton({
    required VoidCallback onTap,
    double iconSize = 22,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.delete_outline, size: iconSize, color: Colors.red),
      ),
    );
  }
}
