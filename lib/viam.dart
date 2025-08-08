import 'package:viam_sdk/viam_sdk.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

late Viam _viam;

Future<void> uploadTabularData(
  String img_id,
  String user_classification,
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
          'user_classification': user_classification,
          'image_id': img_id,
        },
      },
    ];

    final List<(DateTime, DateTime)> dataRequestTimes = [
      (DateTime.now(), DateTime.now()),
    ];

    final result = await _viam.dataClient.tabularDataCaptureUpload(
      tabularData,
      '177e6f10-4505-42fe-bf81-bb2867b680a0',
      componentType: "rdk:component:sensor",
      componentName: "qa-app",
      methodName: "Readings",
      dataRequestTimes: dataRequestTimes,
      tags: ["felix_test"],
    );
    print('Tabular data upload result: $result');
  } catch (e) {
    print(e);
  }
}

Future<String> uploadImageData(String imagePath) async {
  print('Uploading image data from $imagePath');
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
      tags: ["felix_test"],
    );
    print('Image data upload result: $result');
    return result;
  } catch (e) {
    print(e);
  }
  return '';
}
