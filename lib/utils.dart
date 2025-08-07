import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

Future<void> analyzeImage(String imagePath) async {
  // Load the TFLite model
  final modelPath = 'assets/model.tflite'; // Update with your model file name
  final interpreter = await loadTFLiteModel(modelPath);
  // Get model input shape
  final inputShape = interpreter.getInputTensor(0).shape;
  final inputType = interpreter.getInputTensor(0).type;

  print('Model input shape: $inputShape');
  print('Model input type: $inputType');

  // Decode the image file bytes
  img.Image? originalImage = img.decodeImage(
    await File(imagePath).readAsBytes(),
  );
  if (originalImage == null) {
    print("Error: Could not decode image.");
    return;
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
  final outputShape = interpreter.getOutputTensor(0).shape;
  print('Model output shape: $outputShape');
  // Prepare output buffer
  var output = List.filled(
    outputShape.reduce((a, b) => a * b),
    0.0,
  ).reshape(outputShape);

  // Run inference
  interpreter.run(input, output);

  print('Inference result: $output');

  // Don't forget to close the interpreter when done
  interpreter.close();
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

/// Convert image to Uint8List for uint8 models
Uint8List _imageToUint8List(img.Image image) {
  final convertedBytes = Uint8List(1 * image.height * image.width * 3);
  int pixelIndex = 0;

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);

      // Extract RGB values using the correct API (no normalization for uint8)
      convertedBytes[pixelIndex++] = pixel.r.toInt();
      convertedBytes[pixelIndex++] = pixel.g.toInt();
      convertedBytes[pixelIndex++] = pixel.b.toInt();
    }
  }

  return convertedBytes;
}
