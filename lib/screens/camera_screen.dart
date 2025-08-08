import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:viam_qa/classification.dart';
import 'package:viam_qa/viam.dart';

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({super.key, required this.camera});

  final CameraDescription camera;

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.camera,
      // Define the resolution to use.
      ResolutionPreset.veryHigh,
    );

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize().then((_) {
      _controller.setFlashMode(FlashMode.always);
      print('Flash enabled automatically');
    });
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take a picture')),
      // You must wait until the controller is initialized before displaying the
      // camera preview. Use a FutureBuilder to display a loading spinner until the
      // controller has finished initializing.
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return CameraPreview(_controller);
          } else {
            // Otherwise, display a loading indicator.
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        // Provide an onPressed callback.
        onPressed: () async {
          // Take the Picture in a try / catch block. If anything goes wrong,
          // catch the error.
          try {
            // Ensure that the camera is initialized.
            await _initializeControllerFuture;
            // Ensure flash is set right before taking the picture
            await _controller.setFlashMode(FlashMode.always);
            print('Flash mode before capture: ${_controller.value.flashMode}');
            // Attempt to take a picture and get the file `image`
            // where it was saved.
            final image = await _controller.takePicture();
            final inference = await analyzeImage(image.path);

            if (!context.mounted) return;

            // If the picture was taken, display it on a new screen.
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DisplayPictureScreen(
                  // Pass the automatically generated path to
                  // the DisplayPictureScreen widget.
                  imagePath: image.path,
                  inference: inference,
                ),
              ),
            );
          } catch (e) {
            // If an error occurs, log the error to the console.
            print(e);
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}

// A widget that displays the picture taken by the user.
class DisplayPictureScreen extends StatefulWidget {
  final String imagePath;
  final List<Map<String, dynamic>> inference;

  const DisplayPictureScreen({
    super.key,
    required this.imagePath,
    required this.inference,
  });

  @override
  State<DisplayPictureScreen> createState() => _DisplayPictureScreenState();
}

class _DisplayPictureScreenState extends State<DisplayPictureScreen> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _uploadViam() async {
    final imgId = await uploadImageData(widget.imagePath);
    await uploadTabularData(imgId, 'USER_OK', widget.inference);
  }

  @override
  Widget build(BuildContext context) {
    print(widget.inference);

    // Default color
    Color borderColor = Colors.red;

    // Find values for VIAM_UNKNOWN, OK, NOK
    double viamUnknown = 0.0;
    double ok = 0.0;
    double nok = 0.0;

    for (var item in widget.inference) {
      if (item['label'] == 'VIAM_UNKNOWN') {
        viamUnknown = (item['confidence'] ?? 0.0).toDouble();
      } else if (item['label'] == 'OK') {
        ok = (item['confidence'] ?? 0.0).toDouble();
      } else if (item['label'] == 'NOK') {
        nok = (item['confidence'] ?? 0.0).toDouble();
      }
    }

    if (viamUnknown > 0.1) {
      borderColor = Colors.yellow;
    } else if (ok > nok) {
      borderColor = Colors.green;
    } else {
      borderColor = Colors.red;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Display the Picture')),
      body: Center(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 4),
          ),
          child: Image.file(File(widget.imagePath)),
        ),
      ),
    );
  }
}
