import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_controller.dart';

class ThemeToggle extends ConsumerWidget {
  const ThemeToggle({super.key, this.onDarkBackground = false});
  final bool onDarkBackground;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: dark ? 'Switch to light mode' : 'Switch to dark mode',
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: onDarkBackground ? Colors.white : null,
        ),
        onPressed: () => ref.read(themeControllerProvider.notifier).toggle(),
        icon: Icon(
          dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          size: 18,
        ),
        label: Text(dark ? 'Light' : 'Dark'),
      ),
    );
  }
}
