import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

class ThemeController extends Notifier<ThemeMode> {
  int _revision = 0;
  bool _disposed = false;
  @override
  ThemeMode build() {
    ref.onDispose(() => _disposed = true);
    _restore();
    return ThemeMode.light;
  }

  Future<void> _restore() async {
    final revision = _revision;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!_disposed && revision == _revision) {
        state = preferences.getBool('reaccess.dark') == true
            ? ThemeMode.dark
            : ThemeMode.light;
      }
    } catch (_) {
      /* Storage is optional in private browsers. */
    }
  }

  Future<void> toggle() async {
    _revision++;
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (!_disposed) {
        await preferences.setBool('reaccess.dark', state == ThemeMode.dark);
      }
    } catch (_) {
      /* Keep the chosen theme for this session. */
    }
  }
}
