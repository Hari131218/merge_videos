import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;

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
  CameraController? controller;
  List<String> videoPaths = [];
  bool isRecording = false;

  bool mergeLoading = true;

  VideoRecorderController(this.camera) {
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    try {
      controller = CameraController(camera, ResolutionPreset.veryHigh);
      await controller?.initialize();
      await startRecording();
      await Future.delayed(const Duration(milliseconds: 200));
      await stopRecording();

      notifyListeners();
    } catch (e, stackTrace) {
      log('Error initializing camera: $e\n$stackTrace');
    }
  }

  Future<void> startRecording() async {
    if (!controller!.value.isRecordingVideo) {
      try {
        await controller?.startVideoRecording();
        isRecording = true;
        log("Video Recording started");
        notifyListeners();
      } catch (e) {
        log(e.toString());
      }
    }
  }

  Future<void> stopRecording() async {
    if (controller!.value.isRecordingVideo) {
      try {
        log("Video Recording stopped");
        // Stop video recording
        XFile videoFile = await controller!.stopVideoRecording();

        // Generate a random number to use in the new file name
        int randomSuffix = math.Random().nextInt(999999); // Adjust as needed

        // Construct the new file name with the random number
        String newFileName = 'REC$randomSuffix.mp4';

        // Get the app's temporary directory
        Directory tempDir = await getTemporaryDirectory();

        // Specify the path for storing the renamed video in the temporary directory
        String newPath = '${tempDir.path}/$newFileName';

        // Create a File object for the original video file
        File originalFile = File(videoFile.path);

        // Create a File object for the new path
        File newFile = File(newPath);

        // Rename the file by copying it to the new path
        await originalFile.copy(newPath);

        videoPaths.add(newFile.path);
        notifyListeners();

        // Optionally, you can save the renamed file to the gallery
        // await GallerySaver.saveVideo(newFile.path);

        log('Video saved to: ${newFile.path}');

        isRecording = false;
        notifyListeners();
      } catch (e) {
        log(e.toString());
      }
    }
  }

  void deleteIndividualVideos() {
    videoPaths.clear();
    notifyListeners();
  }

  fFmpegKitFuntion() async {
    try {
      mergeLoading = false;
      notifyListeners();
      if (videoPaths.length <= 2) {
        log("empty videos list");
        mergeLoading = true;
        notifyListeners();
        return;
      }

      final tempvideolist = videoPaths.sublist(1, videoPaths.length);

      //  A SAMPLE MERGE COMMAND
      //     '-y -i ${videoPaths[1]} -i ${videoPaths[2]} -filter_complex [0:v][1:v]concat=n=2:v=1[outv] -map [outv] -c:v mpeg4 -r 30 ${videoPaths[0]}';

      final paths = List.generate(tempvideolist.length,
              (i) => i == 0 ? " -i ${tempvideolist[i]}" : tempvideolist[i])
          .join(" -i ");

      final mergeVersions =
          List.generate(tempvideolist.length, (i) => "[$i:v]").join("");

      final command =
          '-y $paths -filter_complex ${mergeVersions}concat=n=${tempvideolist.length}:v=1[outv] -map [outv] -c:v mpeg4 -r 30 ${videoPaths[0]}';

      log("command: $command");
      await FFmpegKit.execute(command).then(
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

            // Save the merged video to the gallery
            final save =
                await GallerySaver.saveVideo(videoPaths[0], toDcim: true);

            if (save!) {
              log("video saved to gallery");
              var appDir = (await getTemporaryDirectory()).path;
              Directory(appDir).delete(recursive: true);
              videoPaths.clear();

              await controller?.startVideoRecording();
              isRecording = true;
              await Future.delayed(const Duration(seconds: 2));
              await stopRecording();
              notifyListeners();
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

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
