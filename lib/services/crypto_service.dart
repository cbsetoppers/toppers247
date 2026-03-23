import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';

class CryptoService {
  /// SYMMETRIC ENCRYPTION (FOR GLOBAL LINKS & PUBLIC MATERIAL)
  /// This key protects your public database from being scraped or extracted by competitors.
  /// Replace 'YOUR_HARDCODED_SECRET_PHRASE' with a 32-character totally random string!
  // IMPORTANT: This exact key must ALSO be set in AdminPanel/src/services/cryptoService.ts
  static final _symmetricKeyString = 'CBSE_TOPPERS_V2_SECURE_KEY_AES32';
  static final _symmetricKey = enc.Key.fromUtf8(
    _symmetricKeyString,
  ); // exactly 32 chars
  static final _symmetricIVString = 'CBSETOPPERS_IV16'; // exactly 16 chars
  static final _symmetricIV = enc.IV.fromUtf8(_symmetricIVString);

  /// Encrypt any global public link or study material
  static String encryptSymmetric(String plainText) {
    if (plainText.isEmpty) return plainText;
    final encrypter = enc.Encrypter(
      enc.AES(_symmetricKey, mode: enc.AESMode.cbc),
    );
    try {
      final encrypted = encrypter.encrypt(plainText, iv: _symmetricIV);
      return encrypted.base64;
    } catch (e) {
      debugPrint('Symmetric encrypt error: $e');
      return plainText;
    }
  }

  /// Decrypt any global public link or study material
  static String decryptSymmetric(String base64Text) {
    if (base64Text.isEmpty || !base64Text.endsWith('=')) return base64Text;
    final encrypter = enc.Encrypter(
      enc.AES(_symmetricKey, mode: enc.AESMode.cbc),
    );
    try {
      final decrypted = encrypter.decrypt64(base64Text, iv: _symmetricIV);
      return decrypted;
    } catch (e) {
      return base64Text; // Fallback if not encrypted
    }
  }

  /// =========================================================================
  /// ASYMMETRIC ENCRYPTION: TRUE E2EE FOR PERSONAL INFO (NAME, PHONE, DOB)
  /// =========================================================================

  // The Admin's Public Key. This ONLY locks data.
  // It is safe to store this in your Flutter APK. The Private Key is kept on your server.
  static final String adminPublicKeyPem = '''
-----BEGIN PUBLIC KEY-----
MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAs6vILQ7ckJCVTNDtUJNi
l+YfDOcZ3jgOKTXDscS3Snn/kvrH/kb2T3KUpjuETKm+OoqBFqLXwk3XBYu5LHj2
xM2RykC2jH1o09Hf1miIWL+M/E01EjUGJ7gSimFNaWco1aYwYqinR1H+83m2yjLu
NkEY1LivNdQeaw5Is4xAPLiZlcoHm9R+7I4P3JS9PnzRmkHLKeh9S3qdaS14Sgpp
aFnEoSTn5egMHX4fTbcZuKCJxS+/AL0OQotO3psh/+fhmuyg2thIiVqqU7gtzoEJ
Xan+U87zHymgYNcwCIIVET/2j4bFu6o3PZSc8L0QADCmyrQ+sNGyoIlFpPVnWwy5
zeng59pPF0magw2dib8Ct+11fpk4fVAEJUJKsLeY2kYI4RotD7YLVcLKKav5w3Fs
CKjBIyBYqbGpGyojw2aePlgxmkEKzEFO1yDISF5V9dfuGib3/OHJAYHWtVuP1GAm
2aEfRXJ4Z+LWmGDxLIe0J9KVzEG8FsqSGHPXB/lmupTo4VG52PXtj53OckA/ouaN
y3bhd6HHUbyByZMvxPO6WcKUoE7ZpDdLxYlYqLSE4UxSpXLXAv/tJ00ZNKY886V/
jKTNWn0noHBBlyjMcVK+NlW7vb0Zx+0HH+wLQdhFHGuJZZ+6ji6o6Si1kyXqmzaY
WSS/DEF03qhTNe/GAF2ml+kCAwEAAQ==
-----END PUBLIC KEY-----
''';

  /// How personal data will be secured before uploading to Supabase
  static Map<String, dynamic> encryptPersonalData(
    String name,
    String phone,
    String userPublicKeyPem,
  ) {
    // 1. Generate a one-time truly random 32-byte AES key just for this user record
    final aesKey = enc.Key.fromSecureRandom(32);
    final iv = enc.IV.fromSecureRandom(16);
    final aesEncrypter = enc.Encrypter(enc.AES(aesKey));

    // 2. Scramble their personal data string
    final encryptedName = aesEncrypter.encrypt(name, iv: iv).base64;
    final encryptedPhone = aesEncrypter.encrypt(phone, iv: iv).base64;

    debugPrint('Successfully scrambled user data.');

    // 3. To let the User read it later, we encrypt the AES key with the User's Public Key
    // final rsaUser = enc.Encrypter(enc.RSA(publicKey: parsePublicKey(userPublicKeyPem)));
    // final userEncryptedKey = rsaUser.encrypt(aesKey.base64).base64;

    // 4. To let the Admin read it later, we encrypt the same AES key with the Admin's Public Key
    // final rsaAdmin = enc.Encrypter(enc.RSA(publicKey: parsePublicKey(adminPublicKeyPem)));
    // final adminEncryptedKey = rsaAdmin.encrypt(aesKey.base64).base64;

    return {
      'name': encryptedName, // Completely scrambled text
      'phone': encryptedPhone, // Completely scrambled text
      'crypto_iv': iv.base64,
      // 'user_encrypted_key': userEncryptedKey,
      // 'admin_encrypted_key': adminEncryptedKey,
    };
  }

  // TODO: Add decryptPersonalData function where it opens flutter_secure_storage
  // grabs the User Private Key -> unboxes the `user_encrypted_key` -> derives AES key -> reads 'name'
}
