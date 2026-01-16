import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class FavoriteItem {
  final String title;
  final String image;
  final String link;

  FavoriteItem({
    required this.title,
    required this.image,
    required this.link,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'image': image,
    'link': link,
  };

  factory FavoriteItem.fromJson(Map<String, dynamic> json) => FavoriteItem(
    title: json['title'],
    image: json['image'],
    link: json['link'],
  );
}

class FavoritesProvider with ChangeNotifier {
  List<FavoriteItem> favorites = [];
  final String _fileName = "favorites.json";

  FavoritesProvider() {
    _loadFavorites();
  }

  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<void> _loadFavorites() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final String jsonStr = await file.readAsString();
        final List<dynamic> decoded = json.decode(jsonStr);
        favorites = decoded.map((e) => FavoriteItem.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final file = await _getFile();
      final String jsonStr = json.encode(favorites.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonStr);
    } catch (e) {
      print(e);
    }
  }

  bool isFavorite(String link) {
    return favorites.any((element) => element.link == link);
  }

  void toggleFavorite(String title, String image, String link) {
    final isExist = favorites.any((element) => element.link == link);

    if (isExist) {
      favorites.removeWhere((element) => element.link == link);
    } else {
      favorites.insert(0, FavoriteItem(title: title, image: image, link: link));
    }

    notifyListeners();
    _saveToDisk();
  }

  void removeFavorite(String link) {
    favorites.removeWhere((element) => element.link == link);
    notifyListeners();
    _saveToDisk();
  }
  void clearFavorites() {
    favorites.clear();
    notifyListeners();
    _saveToDisk();
  }
}