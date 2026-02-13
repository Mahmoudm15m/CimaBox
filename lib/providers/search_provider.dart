import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/home_model.dart';

class BrowseItem {
  final int id;
  final String value;

  BrowseItem({required this.id, required this.value});

  factory BrowseItem.fromJson(Map<String, dynamic> json) {
    return BrowseItem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      value: json['value'].toString(),
    );
  }
}

class SearchProvider with ChangeNotifier {
  List<ContentItem> results = [];
  bool isLoading = false;
  String? error;

  // Browse Data
  bool isBrowseLoading = false;
  List<BrowseItem> genres = [];
  List<BrowseItem> qualities = [];
  List<BrowseItem> years = [];

  final String _searchUrl = 'https://ar.syria-live.fun/arb/search';
  final String _browseUrl = 'https://ar.syria-live.fun/arb/all_data';

  Future<void> search(String query, {String type = 'all'}) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final response = await ApiService.post(
        _searchUrl,
        {'query': query, 'type': type},
      );

      if (response != null && response is List) {
        results = response.map((e) => ContentItem.fromJson(e)).toList();
      } else {
        results = [];
      }
    } catch (e) {
      error = "حدث خطأ أثناء البحث";
      results = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchBrowseData() async {
    if (genres.isNotEmpty) return;

    isBrowseLoading = true;
    notifyListeners();

    years = [];
    int currentYear = DateTime.now().year ;
    int startYear = 1932;

    for (int year = currentYear; year >= startYear; year--) {
      years.add(BrowseItem(id: 0, value: year.toString()));
    }


    try {
      final response = await ApiService.get(_browseUrl);

      if (response != null && response is Map<String, dynamic>) {
        if (response['genres'] != null) {
          genres = (response['genres'] as List)
              .map((e) => BrowseItem.fromJson(e))
              .toList();
        }
        if (response['qualities'] != null) {
          qualities = (response['qualities'] as List)
              .map((e) => BrowseItem.fromJson(e))
              .toList();
        }
      }
    } catch (e) {
      print("Error fetching browse data: $e");
    } finally {
      isBrowseLoading = false;
      notifyListeners();
    }
  }

  void clearResults() {
    results = [];
    notifyListeners();
  }
}