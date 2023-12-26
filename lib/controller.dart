import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter/log.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:ffmpeg_kit_flutter/session.dart';
import 'package:ffmpeg_kit_flutter/statistics.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';

class VideoRecorderController extends ChangeNotifier {
  final CameraDescription camera;
  late CameraController controller;
  List<String> videoPaths = [];
  bool isRecording = false;

  bool mergeLoading = true;

  VideoRecorderController(this.camera) {
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    try {
      controller = CameraController(camera, ResolutionPreset.veryHigh);
      await controller.initialize();
      await startRecording();
      await stopRecording();

      notifyListeners();
    } catch (e, stackTrace) {
      log('Error initializing camera: $e\n$stackTrace');
    }
  }

  Future<void> startRecording() async {
    if (!controller.value.isRecordingVideo) {
      try {
        await controller.startVideoRecording();
        isRecording = true;
        log("Video Recording started");
        notifyListeners();
      } catch (e) {
        log(e.toString());
      }
    }
  }

  Future<void> stopRecording() async {
    if (controller.value.isRecordingVideo) {
      try {
        log("Video Recording stopped");
        XFile videoFile = await controller.stopVideoRecording();

        videoPaths.add(videoFile.path);
        log("Video saved at: $videoFile.path");
        isRecording = false;
        notifyListeners();
      } catch (e) {
        log(e.toString());
      }
    }
  }

  Future<void> mergeVideos() async {
    Directory? appDocDir = await getDownloadsDirectory();
    Directory(appDocDir?.path ?? "XXX");
    String outputVideoPath = '${appDocDir?.path ?? "XXX"}/merged_video.mp4';

    String merger =
        '-i ${videoPaths[0]} -i ${videoPaths[1]} -filter_complex \'[0:v]scale=480:640[v0];[1:v]scale=480:640[v1];[v0][0:a][v1][1:a]concat=n=2:v=1:a=1[outv][outa]' +
            '-map \'[outv][outa]' +
            outputVideoPath;

    log("merger $merger");

    final result = await GallerySaver.saveVideo(merger);

    log(result.toString());

    // File(merger).deleteSync();

    if (result!) {
      log('Videos merged successfully!');

      // deleteIndividualVideos();

      // Use gal package instead of GallerySaver
      GallerySaver.saveVideo(outputVideoPath);

      // Use File class instead of Directory class
      File(merger).deleteSync();

      // Use correct syntax for concatenating videos with ffmpeg
      merger = '-c copy$merger';

      merger =
          '[0:v]scale=480:640[v0];[1:v]scale=480:640[v1];[v0][0:a][v1][1:a]concat=n=2:v=1:a=1[outv][outa]$merger';

      log("merger $merger");

      final result = await GallerySaver.saveVideo(merger);

      log(result.toString());
      notifyListeners();
    } else {
      log('Error merging videos.!');
    }
  }

  void deleteIndividualVideos() {
    for (String path in videoPaths) {
      File(path).deleteSync();
    }
    videoPaths.clear();
    notifyListeners();
  }

  fFmpegKitFuntion() {
    try {
      mergeLoading = false;
      notifyListeners();

      final command =
          '-i ${videoPaths[0]} -i ${videoPaths[1]} -filter_complex [0:v][1:v]concat=n=2:v=1[outv] -map [outv] -c:v mpeg4 -r 30 ${videoPaths[2]}';
      FFmpegKit.execute(command).then(
        (Session session) async {
          // final arguments = session.getArguments();

          final returnCode = await session.getReturnCode();
          // The list of logs generated for this execution
          final logs = await session.getLogs();
          final output = await session.getOutput();

          if (ReturnCode.isSuccess(returnCode)) {
            // SUCCESS
            final message = await session.getAllLogsAsString();

            log("Messs $message");

            // Extract the merged video file path from the log messages or output
            final mergedVideoPath = extractMergedVideoPath(message!);
            log("Merged Video Path: $mergedVideoPath");
            log("++--| $output");
            final save = await GallerySaver.saveVideo(videoPaths[2]);

            if (save!) {
              log("video saved to gallery");
            } else {
              log("video not saved to");
            }
            session.cancel();
            mergeLoading = true;
            notifyListeners();
          } else if (ReturnCode.isCancel(returnCode)) {
            // CANCEL
            log("Canceld video files");
          } else {
            // ERROR
            log("Eroorrooroor --------------------------------");
          }
          for (var em in logs) {
            log(em.getMessage().toString());
          }
          log("--------------------------------");
          log(output.toString());
        },
      );

      mergeLoading = true;
      notifyListeners();

      notifyListeners();
    } catch (e, stackTrace) {
      log(stackTrace.toString());
    }
  }

  String? extractMergedVideoPath(String logMessages) {
    final lines = LineSplitter.split(logMessages);

    for (var line in lines) {
      log("----| $line");
      if (line.startsWith("Merged video saved at:")) {
        // Extract the path from the line (assuming the path is everything after the colon)
        final path = line.substring("Merged video saved at:".length).trim();
        return path;
      }
    }
    // Return null if the path is not found
    return null;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
