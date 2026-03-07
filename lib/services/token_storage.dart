import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _tokenKey = 'yandex_access_token';
  static const String _languageKey = 'app_language';
  static const String _themeKey = 'app_theme_mode';
  static const String _accentColorKey = 'app_accent_color';
  static const String _likedTracksKey = 'liked_track_ids';
  static const String _glassEnabledKey = 'glass_enabled';
  static const String _customGifUrlKey = 'custom_gif_url';
  static const String _blurEnabledKey = 'blur_enabled';

  static Future<void> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      print('Токен успешно сохранён!');
      print('Токен: ${token.length > 20 ? token.substring(0, 20) + "..." : token}');
    } catch (e) {
      print('ОШИБКА при сохранении токена: $e');
    }
  }

  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      print('Токен из хранилища: ${token != null ? "есть" : "отсутствует"}');
      return token;
    } catch (e) {
      print('ОШИБКА при чтении токена: $e');
      return null;
    }
  }

  static Future<void> deleteToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      print('Токен удалён');
    } catch (e) {
      print('ОШИБКА при удалении токена: $e');
    }
  }

  static Future<void> saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }

  static Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey);
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.toString());
  }

  static Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_themeKey);

    if (value == ThemeMode.light.toString()) return ThemeMode.light;
    if (value == ThemeMode.dark.toString()) return ThemeMode.dark;
    return ThemeMode.dark;
  }

  static Future<void> saveAccentColor(int colorValue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentColorKey, colorValue);
  }

  static Future<int> getAccentColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_accentColorKey) ?? Colors.cyanAccent.value;
  }

  static Future<void> saveGlassEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_glassEnabledKey, value);
  }

  static Future<bool> getGlassEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_glassEnabledKey) ?? false;
  }

  static Future<void> saveLikedTrackIds(List<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_likedTracksKey, ids);
      print('Лайкнутые треки сохранены: ${ids.length} шт.');
    } catch (e) {
      print('ОШИБКА при сохранении лайкнутых треков: $e');
    }
  }

  static Future<List<String>> getLikedTrackIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_likedTracksKey) ?? [];
      print('Загружено лайкнутых треков: ${ids.length} шт.');
      return ids;
    } catch (e) {
      print('ОШИБКА при чтении лайкнутых треков: $e');
      return [];
    }
  }

  static Future<void> clearLikedTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_likedTracksKey);
      print('Все лайкнутые треки удалены');
    } catch (e) {
      print('ОШИБКА при очистке лайкнутых треков: $e');
    }
  }

  static Future<void> saveCustomGifUrl(String? url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (url == null || url.trim().isEmpty) {
        await prefs.remove(_customGifUrlKey);
        print('GIF-фон удалён');
      } else {
        await prefs.setString(_customGifUrlKey, url.trim());
        print('GIF-фон сохранён: $url');
      }
    } catch (e) {
      print('ОШИБКА при сохранении GIF-ссылки: $e');
    }
  }

  static Future<String?> getCustomGifUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_customGifUrlKey);
    } catch (e) {
      print('ОШИБКА при чтении GIF-ссылки: $e');
      return null;
    }
  }

  static Future<void> saveBlurEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_blurEnabledKey, value);
      print('Размытие фона сохранено: $value');
    } catch (e) {
      print('ОШИБКА при сохранении размытия фона: $e');
    }
  }

  static Future<bool> getBlurEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getBool(_blurEnabledKey) ?? false;
      print('Размытие фона загружено: $value');
      return value;
    } catch (e) {
      print('ОШИБКА при чтении размытия фона: $e');
      return false;
    }
  }
}
