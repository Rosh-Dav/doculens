import 'package:flutter/services.dart';

class LocalAIService {
  static const MethodChannel _channel = MethodChannel('com.doculens.ai/local');

  /// Submits an image/text to the on-device AI for extraction.
  /// Returns a JSON string matching the InspectionExtraction schema,
  /// or null if the local model fails/is unavailable.
  static Future<String?> extractInspection(
    String text, {
    String? imagePath,
  }) async {
    try {
      final String? jsonResult = await _channel.invokeMethod('extract', {
        'text': text,
        'imagePath': imagePath,
      });
      return jsonResult;
    } on PlatformException catch (e) {
      print("Failed to run local AI extraction: '${e.message}'.");
      return null;
    }
  }
}
