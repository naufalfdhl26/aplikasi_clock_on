import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

class GradientHelper {
  static Widget buildGradientBackground({required Widget child}) {
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.pageBackgroundGradient),
      child: Padding(padding: const EdgeInsets.all(16.0), child: child),
    );
  }
}
