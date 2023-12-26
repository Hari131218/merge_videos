import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';

import 'controller.dart';
import 'home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final cameras = await availableCameras();
    runApp(MyApp(camera: cameras.first));
  } on CameraException catch (e) {
    log('Error: $e.code\nError Message: $e.message');
  }
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({Key? key, required this.camera}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ChangeNotifierProvider(
        create: (context) => VideoRecorderController(camera),
        child: const CameraScreen(),
      ),
    );
  }
}
