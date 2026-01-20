import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class FavoriteItem {
  final int id;
  final String title;
  final String image;

  FavoriteItem({
    required this.title,
    required this.image,
    required this.id,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'image': image,
    'id': id,
  };

  factory FavoriteItem.fromJson(Map<String, dynamic> json) => FavoriteItem(
    title: json['title'],
    image: json['image'],
    id: json['id'],
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

  bool isFavorite(int id) {
    return favorites.any((element) => element.id == id);
  }

  void toggleFavorite(String title, String image, int id) {
    final isExist = favorites.any((element) => element.id == id);

    if (isExist) {
      favorites.removeWhere((element) => element.id == id);
    } else {
      favorites.insert(0, FavoriteItem(title: title, image: image, id: id));
    }

    notifyListeners();
    _saveToDisk();
  }

  void removeFavorite(int id) {
    favorites.removeWhere((element) => element.id == id);
    notifyListeners();
    _saveToDisk();
  }
  void clearFavorites() {
    favorites.clear();
    notifyListeners();
    _saveToDisk();
  }
}