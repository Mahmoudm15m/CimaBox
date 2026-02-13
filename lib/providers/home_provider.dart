import 'dart:convert';

import 'package:flutter/material.dart';
import '../models/home_model.dart';
import '../services/api_service.dart';
import '../services/cache_helper.dart';

class HomeProvider with ChangeNotifier {
  HomeData? homeData;
  bool isLoading = false;
  String? error;

  List<CategoryItem> categories = [];
  Map<int, List<ContentItem>> categoryPreviews = {};

  final String _baseUrl = 'https://ar.syria-live.fun/arb/home';
  final String _categoryContentUrl = 'https://ar.syria-live.fun/arb/category';

  Future<void> fetchHomeData() async {
    var cachedData = CacheHelper.getData('home_data');
    if (cachedData != null) {
      try {
        final data = jsonDecode(jsonEncode(cachedData));
        homeData = HomeData.fromJson(data);

        if (data['sections'] != null) {
          List<dynamic> secs = data['sections'];
          categories = [];
          for (var sec in secs) {
            if (sec['items'] != null) {
              categories.addAll((sec['items'] as List).map((e) => CategoryItem.fromJson(e)).toList());
            }
          }
        }
        notifyListeners();
      } catch (_) {}
    } else {
      isLoading = true;
      notifyListeners();
    }

    error = null;

    try {
      final data = await ApiService.get(_baseUrl);

      if (data != null) {
        CacheHelper.saveData('home_data', data);
        homeData = HomeData.fromJson(data);

        if (data['sections'] != null) {
          List<dynamic> secs = data['sections'];
          categories = [];
          for (var sec in secs) {
            if (sec['items'] != null) {
              categories.addAll((sec['items'] as List).map((e) => CategoryItem.fromJson(e)).toList());
            }
          }
        }
      } else {
        if (homeData == null) error = 'فشل في تحميل البيانات';
      }
    } catch (e) {
      if (homeData == null) error = 'حدث خطأ: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCategoryPreview(int catId) async {
    if (categoryPreviews.containsKey(catId)) return;

    try {
      final data = await ApiService.post(
        _categoryContentUrl,
        {
          "id": catId,
          "page": 1
        },
      );

      if (data != null) {
        List<dynamic> itemsJson = data['items'];
        List<ContentItem> items = itemsJson.map((e) => ContentItem.fromJson(e)).toList();

        categoryPreviews[catId] = items;
        notifyListeners();
      }
    } catch (e) {
      print("Error fetching category preview for $catId: $e");
    }
  }
}