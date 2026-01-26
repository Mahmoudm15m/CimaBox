import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class SettingsProvider with ChangeNotifier {
  String preferredWatchQuality = '720';
  String preferredDownloadQuality = '720';
  bool sortDescending = true;

  final String _fileName = "settings.json";

  SettingsProvider() {
    _loadSettings();
  }

  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<void> _loadSettings() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final String jsonStr = await file.readAsString();
        final Map<String, dynamic> data = json.decode(jsonStr);
        preferredWatchQuality = data['watch_quality'] ?? '720';
        preferredDownloadQuality = data['download_quality'] ?? '720';
        sortDescending = data['sort_descending'] ?? true;
        notifyListeners();
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final file = await _getFile();
      final String jsonStr = json.encode({
        'watch_quality': preferredWatchQuality,
        'download_quality': preferredDownloadQuality,
        'sort_descending': sortDescending,
      });
      await file.writeAsString(jsonStr);
    } catch (e) {
      print(e);
    }
  }

  void setWatchQuality(String quality) {
    preferredWatchQuality = quality;
    notifyListeners();
    _saveSettings();
  }

  void setDownloadQuality(String quality) {
    preferredDownloadQuality = quality;
    notifyListeners();
    _saveSettings();
  }

  void setSortDescending(bool value) {
    sortDescending = value;
    notifyListeners();
    _saveSettings();
  }

  void validatePremiumSettings(bool isPremium) {
    if (!isPremium) {
      bool hasChanged = false;

      if (preferredWatchQuality == '1080') {
        preferredWatchQuality = '720';
        hasChanged = true;
      }

      if (preferredDownloadQuality == '1080') {
        preferredDownloadQuality = '720';
        hasChanged = true;
      }

      if (hasChanged) {
        notifyListeners();
        _saveSettings();
      }
    }
  }
}