import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/home_model.dart';

class HomeProvider with ChangeNotifier {
  HomeData? homeData;
  bool isLoading = false;
  String? error;

  List<CategoryItem> categories = [];
  Map<String, List<ContentItem>> categoryPreviews = {};

  final Dio _dio = Dio();
  final String _baseUrl = 'https://ar.fastmovies.site/arb/home';
  final String _categoriesUrl = 'https://ar.fastmovies.site/arb/categories';
  final String _categoryContentUrl = 'https://ar.fastmovies.site/arb/category';

  Future<void> fetchHomeData() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await _dio.get(_baseUrl);
      if (response.statusCode == 200) {
        homeData = HomeData.fromJson(response.data);
        // بعد ما نجيب الهوم، نجيب قائمة التصنيفات
        fetchCategories();
      } else {
        error = 'فشل في تحميل البيانات: ${response.statusCode}';
      }
    } catch (e) {
      error = 'حدث خطأ: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCategories() async {
    try {
      final response = await _dio.get(
        _categoriesUrl,
        options: Options(headers: {'accept': 'application/json'}),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = response.data;
        categories = data.map((e) => CategoryItem.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      print("Error fetching categories: $e");
    }
  }

  Future<void> fetchCategoryPreview(String url) async {
    if (categoryPreviews.containsKey(url)) return;

    try {
      final response = await _dio.post(
        _categoryContentUrl,
        data: {
          "url": url,
          "page": 1
        },
        options: Options(headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json'
        }),
      );

      if (response.statusCode == 200) {
        List<dynamic> itemsJson = response.data['items'];
        List<ContentItem> items = itemsJson.map((e) => ContentItem.fromJson(e)).toList();

        categoryPreviews[url] = items;
        notifyListeners();
      }
    } catch (e) {
      print("Error fetching category preview for $url: $e");
    }
  }
}