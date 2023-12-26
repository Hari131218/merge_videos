import 'dart:developer';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:merge_videos/video_player.dart';
import 'package:provider/provider.dart';

import 'controller.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final videoController = Provider.of<VideoRecorderController>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Example'),
        actions: [
          IconButton.outlined(
              onPressed: () async {
                try {
                  FilePickerResult? result =
                      await FilePicker.platform.pickFiles();

                  log((result?.paths).toString());
                } catch (e, s) {
                  log(s.toString());
                }
              },
              icon: const Icon(Icons.file_open_rounded))
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 300,
            child: CameraPreview(videoController.controller),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              videoController.isRecording
                  ? videoController.stopRecording()
                  : videoController.startRecording();
            },
            child: Text(videoController.isRecording
                ? "Stop Recording"
                : "Start Recording"),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (!videoController.isRecording) {
                videoController.fFmpegKitFuntion();
              }
            },
            child: videoController.mergeLoading != true
                ? const CircularProgressIndicator(
                    color: Colors.black,
                  )
                : const Text("Merge Videos"),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: videoController.videoPaths.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => VideoPlayerScreen(
                          videoPath: videoController.videoPaths[index]),
                    ));
                  },
                  child: ListTile(
                    title: Text("Video ${index + 1}"),
                    subtitle: Text(videoController.videoPaths[index - 1]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
