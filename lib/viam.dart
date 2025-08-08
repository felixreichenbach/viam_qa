import 'package:viam_sdk/viam_sdk.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

late Viam _viam;

Future<void> uploadTabularData(
  String imgId,
  String userClassification,
  List<Map<String, dynamic>> inference,
) async {
  try {
    _viam = await Viam.withApiKey(
      dotenv.env['API_KEY_ID'] ?? '',
      dotenv.env['API_KEY'] ?? '',
    );

    final List<Map<String, dynamic>> tabularData;
    tabularData = [
      {
        'readings': {
          'classifications': inference,
          'user_classification': userClassification,
          'image_id': imgId,
        },
      },
    ];

    final List<(DateTime, DateTime)> dataRequestTimes = [
      (DateTime.now(), DateTime.now()),
    ];

    final _ = await _viam.dataClient.tabularDataCaptureUpload(
      tabularData,
      '177e6f10-4505-42fe-bf81-bb2867b680a0',
      componentType: "rdk:component:sensor",
      componentName: "qa-app",
      methodName: "Readings",
      dataRequestTimes: dataRequestTimes,
      tags: ["test"],
    );
  } catch (e) {
    print(e);
  }
}

Future<String> uploadImageData(
  String imagePath,
  List<Map<String, dynamic>> inference,
  String userRating,
) async {
  // Extract the classification with the higher score from inference
  String mlRating = '';
  if (inference.isNotEmpty) {
    inference.sort((a, b) {
      final aConfidence = (a['confidence'] as num?) ?? 0.0;
      final bConfidence = (b['confidence'] as num?) ?? 0.0;
      return bConfidence.compareTo(aConfidence);
    });
    mlRating = inference.first['label'] ?? '';
  }
  try {
    _viam = await Viam.withApiKey(
      dotenv.env['API_KEY_ID'] ?? '',
      dotenv.env['API_KEY'] ?? '',
    );

    final image = File(imagePath);
    final imageBytes = await image.readAsBytes();

    (DateTime, DateTime) dataRequestTimes = (DateTime.now(), DateTime.now());

    final result = await _viam.dataClient.binaryDataCaptureUpload(
      imageBytes,
      '177e6f10-4505-42fe-bf81-bb2867b680a0',
      componentType: "rdk:component:camera",
      componentName: "camera",
      methodName: "ReadImage",
      '.jpg',
      dataRequestTimes: dataRequestTimes,
      tags: ["flutter", userRating, mlRating],
    );
    print('Image data upload result: $result');
    return result;
  } catch (e) {
    print(e);
  }
  return '';
}
