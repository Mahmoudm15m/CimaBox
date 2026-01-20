import 'package:flutter/material.dart';
import '../models/home_model.dart';
import '../services/api_service.dart';

class SearchProvider with ChangeNotifier {
  List<ContentItem> results = [];
  bool isLoading = false;
  String? error;

  final String _url = 'https://ar.fastmovies.site/arb/search';

  Future<void> search(String query, {String type = 'all'}) async {
    if (query.isEmpty) return;

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final data = await ApiService.post(
        _url,
        {
          "query": query,
          "type": type
        },
      );

      if (data != null) {
        List<dynamic> jsonList = data;
        results = jsonList.map((e) => ContentItem.fromJson(e)).toList();
      } else {
        error = 'لا توجد نتائج أو حدث خطأ';
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