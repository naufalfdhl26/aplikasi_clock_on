import 'package:flutter/material.dart';

class AvatarHelper {
  // Widget avatar dengan animasi
  static Widget buildAvatar({
    String?
    avatarPath, // path avatar yang dipilih (contoh: 'assets/karyawan1.jpeg')
    required double radius,
    bool showBorder = false,
  }) {
    // Default avatar jika belum dipilih
    final String assetPath = avatarPath != null && avatarPath.isNotEmpty
        ? avatarPath
        : 'assets/karyawan1.jpeg';

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white, // full white card feel
                border: showBorder
                    ? Border.all(color: Colors.white, width: 4)
                    : null,
                boxShadow: showBorder
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Image.asset(assetPath, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Widget avatar sederhana tanpa animasi (untuk list item dll)
  static Widget buildSimpleAvatar({
    String? avatarPath,
    required double radius,
  }) {
    // Default avatar jika belum dipilih
    final String assetPath = avatarPath != null && avatarPath.isNotEmpty
        ? avatarPath
        : 'assets/karyawan1.jpeg';

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Image.asset(assetPath, fit: BoxFit.contain),
        ),
      ),
    );
  }

  // List avatar yang tersedia
  static const List<String> availableAvatars = [
    'assets/karyawan1.jpeg',
    'assets/karyawan2.jpeg',
    'assets/karyawan3.jpeg',
    'assets/karyawan4.jpeg',
    'assets/karyawan5.jpeg',
    'assets/karyawan6.jpeg',
    'assets/karyawan7.jpeg',
    'assets/karyawan8.jpeg',
    'assets/karyawan9.jpeg',
    'assets/karyawan10.jpeg',
  ];
}
