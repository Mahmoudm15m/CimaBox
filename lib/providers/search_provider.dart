import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/home_model.dart';

class SearchProvider with ChangeNotifier {
  List<ContentItem> results = [];
  bool isLoading = false;
  String? error;

  final Dio _dio = Dio();
  final String _url = 'https://ar.fastmovies.site/arb/search';

  Future<void> search(String query, {String type = 'all'}) async {
    if (query.isEmpty) return;

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await _dio.post(
        _url,
        data: {
          "query": query,
          "type": type
        },
        options: Options(headers: {
          'Content-Type': 'application/json',
          'accept': 'application/json',
        }),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = response.data;
        results = data.map((e) => ContentItem.fromJson(e)).toList();
      } else {
        error = 'حدث خطأ: ${response.statusCode}';
      }
    } catch (e) {
      error = 'تأكد من الاتصال بالإنترنت';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clearResults() {
    results = [];
    notifyListeners();
  }
}