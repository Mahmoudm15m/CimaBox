import 'package:hive_flutter/hive_flutter.dart';

class CacheHelper {
  static const String _boxName = 'app_cache';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  static dynamic getData(String key) {
    return Hive.box(_boxName).get(key);
  }

  static Future<void> saveData(String key, dynamic value) async {
    await Hive.box(_boxName).put(key, value);
  }

  static bool hasData(String key) {
    return Hive.box(_boxName).containsKey(key);
  }

  static Future<void> clearApiCacheOnly() async {
    final box = Hive.box(_boxName);
    final keys = box.keys.toList();

    for (var key in keys) {
      String keyString = key.toString();
      if (keyString.startsWith('home_') ||
          keyString.startsWith('details_') ||
          keyString.startsWith('servers_') ||
          keyString == 'home_data') {

        await box.delete(key);
      }
    }
  }

}