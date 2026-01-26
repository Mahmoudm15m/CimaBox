import 'package:flutter/material.dart';
import '../models/actor_model.dart';
import '../services/api_service.dart';

class ActorProvider with ChangeNotifier {
  ActorModel? actor;
  bool isLoading = false;
  String? error;

  final String _url = 'https://ar.fastmovies.site/arb/actor';

  Future<void> fetchActor(int id) async {
    isLoading = true;
    error = null;
    actor = null;
    notifyListeners();

    try {
      final data = await ApiService.post(
        _url,
        {"id": id},
      );

      if (data != null) {
        actor = ActorModel.fromJson(data);
      } else {
        error = 'فشل تحميل البيانات';
      }
    } catch (e) {
      error = 'حدث خطأ: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}