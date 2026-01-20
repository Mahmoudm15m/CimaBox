import 'package:flutter/material.dart';
import '../models/home_model.dart';
import '../services/api_service.dart';

class CategoryProvider with ChangeNotifier {
  List<ContentItem> items = [];
  bool isLoading = false;
  bool isMoreLoading = false;
  bool hasMore = true;
  int currentPage = 1;
  int? currentId;

  final String _categoryContentUrl = 'https://ar.fastmovies.site/arb/category';

  Future<void> fetchCategory(int id, {bool refresh = false}) async {
    if (refresh) {
      items = [];
      currentPage = 1;
      hasMore = true;
      currentId = id;
      isLoading = true;
      notifyListeners();
    } else {
      if (!hasMore || isMoreLoading) return;
      isMoreLoading = true;
      notifyListeners();
    }

    try {
      final data = await ApiService.post(
        _categoryContentUrl,
        {
          "id": id,
          "page": currentPage
        },
      );

      if (data != null) {
        List<dynamic> newItemsJson = data['items'];
        List<ContentItem> newItems = newItemsJson.map((e) => ContentItem.fromJson(e)).toList();

        if (refresh) {
          items = newItems;
        } else {
          final existingIds = items.map((i) => i.title).toSet();
          final distinctNewItems = newItems.where((i) => !existingIds.contains(i.title)).toList();
          items.addAll(distinctNewItems);
        }

        if (data['pagination'] != null) {
          hasMore = data['pagination']['has_next'] ?? false;
        } else {
          hasMore = newItems.isNotEmpty;
        }

        if (hasMore) currentPage++;
      }
    } catch (e) {
      print("Error loading category: $e");
    } finally {
      isLoading = false;
      isMoreLoading = false;
      notifyListeners();
    }
  }
}