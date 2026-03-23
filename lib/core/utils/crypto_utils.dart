import 'dart:convert';

class CryptoUtils {
  static String decode(String encoded, String key) {
    List<int> bytes = base64.decode(encoded);
    List<int> keyBytes = utf8.encode(key);
    List<int> result = [];
    for (int i = 0; i < bytes.length; i++) {
      result.add(bytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return utf8.decode(result);
  }

  static String encode(String plain, String key) {
    List<int> plainBytes = utf8.encode(plain);
    List<int> keyBytes = utf8.encode(key);
    List<int> result = [];
    for (int i = 0; i < plainBytes.length; i++) {
      result.add(plainBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return base64.encode(result);
  }
}
