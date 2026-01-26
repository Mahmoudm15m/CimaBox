import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../secrets.dart';

class ApiService {
  static final _key = encrypt.Key.fromBase64(getEncryptionKey());
  static final _fernet = encrypt.Fernet(_key);
  static final _encrypter = encrypt.Encrypter(_fernet);

  static String? userToken;

  static Function(bool isPremium)? onPremiumStateChange;

  static Map<String, String> _getSecurityHeaders() {
    String timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).toString();
    var bytes = utf8.encode("$timestamp${getAppSecret()}");
    var digest = sha256.convert(bytes);

    Map<String, String> headers = {
      "X-App-Time": timestamp,
      "X-App-Hash": digest.toString(),
      "Content-Type": "application/json",
      "accept": "application/json",
    };

    if (userToken != null) {
      headers['Authorization'] = 'Bearer $userToken';
    }

    return headers;
  }

  static String _decryptResponse(String encryptedBody) {
    try {
      final decrypted = _encrypter.decrypt64(encryptedBody);
      return decrypted;
    } catch (e) {
      return "{}";
    }
  }

  static void _checkPremiumStatus(dynamic data) {
    if (data is Map<String, dynamic> && data.containsKey('is_premium')) {
      bool status = data['is_premium'] == true;
      if (onPremiumStateChange != null) {
        onPremiumStateChange!(status);
      }
    }
  }

  static Future<dynamic> get(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: _getSecurityHeaders(),
      );

      if (response.statusCode == 200) {
        String jsonString = _decryptResponse(response.body);
        var data = jsonDecode(jsonString);

        _checkPremiumStatus(data);

        return data;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<dynamic> post(String url, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: _getSecurityHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        String jsonString = _decryptResponse(response.body);
        var data = jsonDecode(jsonString);

        _checkPremiumStatus(data);

        return data;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}