import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
  final ClassificationService _classificationService = ClassificationService();
  bool _classificationInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize().then((_) {
      _controller.setFlashMode(FlashMode.always);
      print('Flash enabled automatically');
    });
    _classificationService.init().then((_) {
      setState(() {
        _classificationInitialized = true;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _classificationService.dispose();
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
        onPressed: !_classificationInitialized
            ? null
            : () async {
                try {
                  await _initializeControllerFuture;
                  await _controller.setFlashMode(FlashMode.always);
                  print(
                      'Flash mode before capture: \\${_controller.value.flashMode}');
                  final image = await _controller.takePicture();
                  final imageBytes = await image.readAsBytes();
                  final inference =
                      await _classificationService.analyzeImage(imageBytes);

                  if (!context.mounted) return;

                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => DisplayPictureScreen(
                        imageBytes: imageBytes,
                        inference: inference,
                      ),
                    ),
                  );
                } catch (e) {
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
  final Uint8List imageBytes;
  final List<Map<String, dynamic>> inference;

  const DisplayPictureScreen({
    super.key,
    required this.imageBytes,
    required this.inference,
  });

  @override
  State<DisplayPictureScreen> createState() => _DisplayPictureScreenState();
}

class _DisplayPictureScreenState extends State<DisplayPictureScreen> {
  // User image rating - null means no choice made yet
  bool? userRatingOK;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _uploadViam() async {
    widget.imageBytes;
    final imgId = await uploadImageData(
      widget.imageBytes,
      widget.inference,
      userRatingOK!
          ? 'USER_OK'
          : 'USER_NOK', // ! is safe here because we check before calling
    );
    await uploadTabularData(
      imgId,
      userRatingOK! ? 'USER_OK' : 'USER_NOK',
      widget.inference,
    );
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
      appBar: AppBar(title: const Text('Picture')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor, width: 4),
                ),
                child: Image.memory(widget.imageBytes, fit: BoxFit.contain),
              ),
            ),
          ),
          // Rating section
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(
                          Icons.check_circle,
                          color: userRatingOK == true
                              ? Colors.white
                              : Colors.green,
                        ),
                        label: const Text('OK'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: userRatingOK == true
                              ? Colors.green
                              : Colors.grey[300],
                          foregroundColor: userRatingOK == true
                              ? Colors.white
                              : Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          setState(() {
                            userRatingOK = true;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(
                          Icons.cancel,
                          color:
                              userRatingOK == false ? Colors.white : Colors.red,
                        ),
                        label: const Text('NOK'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: userRatingOK == false
                              ? Colors.red
                              : Colors.grey[300],
                          foregroundColor: userRatingOK == false
                              ? Colors.white
                              : Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          setState(() {
                            userRatingOK = false;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding:
            const EdgeInsets.only(bottom: 80.0), // Move FAB up by 80 pixels
        child: FloatingActionButton(
          // Disable the button if no choice has been made
          onPressed: userRatingOK == null
              ? null
              : () async {
                  try {
                    // Upload the image to Viam
                    await _uploadViam();

                    // Show a snackbar to indicate success
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Image uploaded successfully!'),
                      ),
                    );

                    // Navigate back
                    Navigator.pop(context);
                  } catch (e) {
                    // Show error message
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                        SnackBar(content: Text('Upload failed: $e')));
                  }
                },
          backgroundColor: userRatingOK == null ? Colors.grey : null,
          child: const Icon(Icons.cloud_upload),
        ),
      ),
    );
  }
}
