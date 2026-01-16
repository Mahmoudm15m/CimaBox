import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class HistoryItem {
  final String id;
  final String title;
  final String image;
  final String link;
  final int positionMs;
  final int durationMs;
  final DateTime lastWatched;
  final String? quality;

  HistoryItem({
    required this.id,
    required this.title,
    required this.image,
    required this.link,
    required this.positionMs,
    required this.durationMs,
    required this.lastWatched,
    this.quality,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'image': image,
    'link': link,
    'positionMs': positionMs,
    'durationMs': durationMs,
    'lastWatched': lastWatched.toIso8601String(),
    'quality': quality,
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    id: json['id'],
    title: json['title'],
    image: json['image'],
    link: json['link'],
    positionMs: json['positionMs'] ?? 0,
    durationMs: json['durationMs'] ?? 0,
    lastWatched: DateTime.parse(json['lastWatched']),
    quality: json['quality'],
  );
}

class WatchHistoryProvider with ChangeNotifier {
  List<HistoryItem> history = [];
  final String _fileName = "watch_history.json";

  WatchHistoryProvider() {
    _loadHistory();
  }

  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<void> _loadHistory() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final String jsonStr = await file.readAsString();
        final List<dynamic> decoded = json.decode(jsonStr);
        history = decoded.map((e) => HistoryItem.fromJson(e)).toList();
        history.sort((a, b) => b.lastWatched.compareTo(a.lastWatched));
        notifyListeners();
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final file = await _getFile();
      final String jsonStr = json.encode(history.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonStr);
    } catch (e) {
      print(e);
    }
  }

  void saveProgress({
    required String link,
    required String title,
    required String image,
    required int positionMs,
    required int durationMs,
    String? quality,
  }) {
    history.removeWhere((item) => item.link == link);

    final newItem = HistoryItem(
      id: link,
      title: title,
      image: image,
      link: link,
      positionMs: positionMs,
      durationMs: durationMs,
      lastWatched: DateTime.now(),
      quality: quality,
    );

    history.insert(0, newItem);
    notifyListeners();
    _saveToDisk();
  }

  int getSavedPosition(String link) {
    final item = history.firstWhere(
          (element) => element.link == link,
      orElse: () => HistoryItem(id: '', title: '', image: '', link: '', positionMs: 0, durationMs: 0, lastWatched: DateTime.now()),
    );
    return item.positionMs;
  }

  void removeItem(String link) {
    history.removeWhere((item) => item.link == link);
    notifyListeners();
    _saveToDisk();
  }

  void clearHistory() {
    history.clear();
    notifyListeners();
    _saveToDisk();
  }
  
}