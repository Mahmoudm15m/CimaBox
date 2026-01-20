import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../secrets.dart';

class ApiService {
  static final _key = encrypt.Key.fromBase64(getEncryptionKey());
  static final _fernet = encrypt.Fernet(_key);
  static final _encrypter = encrypt.Encrypter(_fernet);

  static Map<String, String> _getSecurityHeaders() {
    String timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).toString();
    var bytes = utf8.encode("$timestamp${getAppSecret()}");
    var digest = sha256.convert(bytes);

    return {
      "X-App-Time": timestamp,
      "X-App-Hash": digest.toString(),
      "Content-Type": "application/json",
      "accept": "application/json",
    };
  }

  static String _decryptResponse(String encryptedBody) {
    try {
      final decrypted = _encrypter.decrypt64(encryptedBody);
      return decrypted;
    } catch (e) {
      return "{}";
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
        return jsonDecode(jsonString);
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
        return jsonDecode(jsonString);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}