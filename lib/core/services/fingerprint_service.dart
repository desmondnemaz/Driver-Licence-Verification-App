import 'package:flutter/services.dart';
import 'dart:typed_data';

class FingerprintService {
  static const _platform = MethodChannel('com.finger.get/battery');

  /// Initializes the hardware and powers on the sensor
  Future<bool> initializeScanner() async {
    try {
      final int result = await _platform.invokeMethod('opendev');
      return result == 0;
    } on PlatformException catch (e) {
      print("Scanner Init Error: ${e.message}");
      return false;
    }
  }

  /// Captures a finger and returns both the Template (String) and Image (Bytes)
  Future<Map<String, dynamic>?> enrollFinger() async {
    try {
      final result = await _platform.invokeMethod('enroll');
      if (result != null) {
        return {
          'template': result['text'], // The Base64 string for DB storage
          'image': result['bytes'],   // The BMP bytes for UI display
        };
      }
    } on PlatformException catch (e) {
      print("Enroll Error: ${e.message}");
    }
    return null;
  }

  /// Searches for a match against a list of provided templates
  Future<int> searchFinger(List<String> templates, {int timeoutMs = 15000}) async {
    try {
      final result = await _platform.invokeMethod('search', {
        'fpcharlist': templates,
        'time': timeoutMs,
      });
      return result['id'] ?? -1; // Returns the index of the matched template
    } on PlatformException catch (e) {
      print("Search Error: ${e.message}");
      return -1;
    }
  }
}