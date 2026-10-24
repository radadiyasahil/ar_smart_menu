import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemePreference {
  light('light', 'Light'),
  dark('dark', 'Dark');

  const ThemePreference(this.storageKey, this.label);

  final String storageKey;
  final String label;

  static ThemePreference fromKey(String? key) => ThemePreference.values.firstWhere(
        (e) => e.storageKey == key,
        orElse: () => ThemePreference.light,
      );
}

class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'theme_preference';

  ThemePreference _preference = ThemePreference.light;

  ThemePreference get preference => _preference;

  ThemeMode get themeMode => switch (_preference) {
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
      };

  Future<void> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    _preference = ThemePreference.fromKey(prefs.getString(_prefKey));
    notifyListeners();
  }

  Future<void> setPreference(ThemePreference preference) async {
    if (_preference == preference) return;
    _preference = preference;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, preference.storageKey);
  }
}
