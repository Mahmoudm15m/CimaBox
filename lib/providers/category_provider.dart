import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/home_model.dart';

class CategoryProvider with ChangeNotifier {
  List<ContentItem> items = [];
  bool isLoading = false;
  bool isMoreLoading = false;
  bool hasMore = true;
  int currentPage = 1;
  String? currentUrl;

  final Dio _dio = Dio();
  final String _categoryContentUrl = 'https://ar.fastmovies.site/arb/category';

  Future<void> fetchCategory(String url, {bool refresh = false}) async {
    if (refresh) {
      items = [];
      currentPage = 1;
      hasMore = true;
      currentUrl = url;
      isLoading = true;
      notifyListeners();
    } else {
      if (!hasMore || isMoreLoading) return;
      isMoreLoading = true;
      notifyListeners();
    }

    try {
      final response = await _dio.post(
        _categoryContentUrl,
        data: {
          "url": url,
          "page": currentPage
        },
        options: Options(headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json'
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        List<dynamic> newItemsJson = data['items'];
        List<ContentItem> newItems = newItemsJson.map((e) => ContentItem.fromJson(e)).toList();

        if (refresh) {
          items = newItems;
        } else {
          items.addAll(newItems);
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