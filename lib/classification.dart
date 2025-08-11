import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;

class ClassificationService {
  late Interpreter _interpreter;
  late List<String> _labels;
  bool _initialized = false;

  Future<void> init({
    String modelPath = 'assets/model.tflite',
    String labelsPath = 'assets/labels.txt',
  }) async {
    _interpreter = await _loadTFLiteModel(modelPath);
    _labels = await _loadLabels(labelsPath);
    _initialized = true;
    print('Model and labels loaded successfully.');
  }

  Future<List<Map<String, dynamic>>> analyzeImage(Uint8List imageBytes) async {
    if (!_initialized) {
      throw Exception(
          'ClassificationService not initialized. Call init() first.');
    }

    print('Labels: \\$_labels');

    // Get model input shape
    final inputShape = _interpreter.getInputTensor(0).shape;
    final inputType = _interpreter.getInputTensor(0).type;
    print('Model input shape: $inputShape');
    print('Model input type: $inputType');

    // Decode the image file bytes
    img.Image? originalImage = img.decodeImage(
      imageBytes,
    );
    if (originalImage == null) {
      print("Error: Could not decode image.");
      return [];
    }
    // Resize the image to the input size expected by the model
    img.Image resizedImage = img.copyResize(
      originalImage,
      width: 256,
      height: 256,
    );

    // Create input tensor
    var input = _imageToUint8List(resizedImage);

    // Get output shape
    final outputShape = _interpreter.getOutputTensor(0).shape;
    print('Model output shape: $outputShape');
    // Prepare output buffer
    var output = List.filled(
      outputShape.reduce((a, b) => a * b),
      0.0,
    ).reshape(outputShape);

    // Run inference
    _interpreter.run(input, output);

    // Process results with labels
    final predictions = output[0] as List<double>;
    final results = _processResults(predictions, _labels);

    print('=== Classification Results ===');
    for (int i = 0; i < results.length && i < 5; i++) {
      final result = results[i];
      print(
        '${i + 1}. ${result['label']}: \\${(result['confidence'] * 100).toStringAsFixed(2)}%',
      );
    }

    return results;
  }

  void dispose() {
    if (_initialized) {
      _interpreter.close();
      _initialized = false;
    }
  }

  Future<Interpreter> _loadTFLiteModel(String modelPath) async {
    try {
      final interpreter = await Interpreter.fromAsset(modelPath);
      print('TFLite model loaded from: $modelPath');
      return interpreter;
    } catch (e) {
      print('Failed to load TFLite model: $e');
      rethrow;
    }
  }

  Uint8List _imageToUint8List(img.Image image) {
    final convertedBytes = Uint8List(1 * image.height * image.width * 3);
    int pixelIndex = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        convertedBytes[pixelIndex++] = pixel.r.toInt();
        convertedBytes[pixelIndex++] = pixel.g.toInt();
        convertedBytes[pixelIndex++] = pixel.b.toInt();
      }
    }

    return convertedBytes;
  }

  Future<List<String>> _loadLabels(String labelsPath) async {
    try {
      final labelsData = await rootBundle.loadString(labelsPath);
      final labels = labelsData
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      print('Successfully loaded \\${labels.length} labels from $labelsPath');
      return labels;
    } catch (e) {
      print('Error loading labels from $labelsPath: $e');
      // Return generic labels as fallback
      return List.generate(1000, (index) => 'Class_\\$index');
    }
  }

  List<Map<String, dynamic>> _processResults(
    List<double> predictions,
    List<String> labels,
  ) {
    final results = <Map<String, dynamic>>[];

    for (int i = 0; i < predictions.length; i++) {
      results.add({
        'index': i,
        'label': i < labels.length ? labels[i] : 'Unknown_\\$i',
        'confidence': predictions[i],
      });
    }

    return results;
  }
}

Future<Interpreter> loadTFLiteModel(String modelPath) async {
  try {
    final interpreter = await Interpreter.fromAsset(modelPath);
    print('TFLite model loaded from: $modelPath');
    return interpreter;
  } catch (e) {
    print('Failed to load TFLite model: $e');
    rethrow;
  }
}

/// Load labels from assets file
Future<List<String>> loadLabels(String labelsPath) async {
  try {
    final labelsData = await rootBundle.loadString(labelsPath);
    final labels = labelsData
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    print('Successfully loaded ${labels.length} labels from $labelsPath');
    return labels;
  } catch (e) {
    print('Error loading labels from $labelsPath: $e');
    // Return generic labels as fallback
    return List.generate(1000, (index) => 'Class_$index');
  }
}

/// Process inference results and return sorted predictions with labels
List<Map<String, dynamic>> processResults(
  List<double> predictions,
  List<String> labels,
) {
  final results = <Map<String, dynamic>>[];

  for (int i = 0; i < predictions.length; i++) {
    results.add({
      'index': i,
      'label': i < labels.length ? labels[i] : 'Unknown_$i',
      'confidence': predictions[i],
    });
  }

  return results;
}
