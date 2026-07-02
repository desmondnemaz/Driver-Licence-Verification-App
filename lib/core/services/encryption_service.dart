import 'package:encrypt/encrypt.dart' as enc;

class EncryptionService {
  // Hardcoded default 32-byte key and 16-byte IV.
  // In production, these should be loaded from secure environment variables.
  static final _key = enc.Key.fromUtf8('my32charultrasecretkeyforaes256!'); 
  static final _iv = enc.IV.fromUtf8('my16charsecureiv');

  static final _encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));

  /// Encrypts the input text. Returns base64 encoded ciphertext.
  static String encrypt(String text) {
    if (text.isEmpty) return text;
    try {
      final encrypted = _encrypter.encrypt(text, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      return text;
    }
  }

  /// Decrypts the input base64 encoded ciphertext.
  /// If decryption fails (e.g., for existing plaintext entries), returns the original text.
  static String decrypt(String encryptedText) {
    if (encryptedText.isEmpty) return encryptedText;
    try {
      // Basic check: if it's too short or not base64, it's likely plaintext.
      if (encryptedText.length < 16) return encryptedText;
      final decrypted = _encrypter.decrypt64(encryptedText, iv: _iv);
      return decrypted;
    } catch (e) {
      // Fallback for plaintext data already in DB
      return encryptedText;
    }
  }

  /// Checks if the text is encrypted.
  /// If decryption succeeds and returns a string different from the input, it is encrypted.
  static bool isEncrypted(String text) {
    if (text.isEmpty) return false;
    try {
      if (text.length < 16) return false;
      final decrypted = _encrypter.decrypt64(text, iv: _iv);
      return decrypted != text;
    } catch (_) {
      return false;
    }
  }
}
