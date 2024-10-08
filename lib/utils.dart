import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:video_compress/video_compress.dart';
import 'package:path/path.dart' as path;

enum NotifyType {
  success,
  warning,
  error,
}

void notify(BuildContext context, String message, NotifyType type) {
  var mapTypes = <NotifyType, Color>{
    NotifyType.success: const Color(0xFF3065CC),
    NotifyType.warning: Colors.orange,
    NotifyType.error: Colors.red,
  };

  showDialog(
      context: context,
      builder: (context) {
        return Center(
          child: Wrap(children: [
            Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(10))),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: mapTypes[type],
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none),
                )),
          ]),
        );
      });
}

Future<Uint8List?> compressImage(Uint8List imageData) async {
  final result = await FlutterImageCompress.compressWithList(
    imageData,
    minHeight: 1920, // Adjust as needed
    minWidth: 1080, // Adjust as needed
    quality: 70, // Compression quality (0-100)
  );
  return result;
}

Future<String> makePdfFromImages(List<XFile> images) async {
  if (images.isEmpty) {
    return '';
  }

  final pdf = pw.Document();

  for (var img in images) {
    File file = File(img.path);
    //compress the quality of image
    var compressedImage = await compressImage(await file.readAsBytes());
    final image = pw.MemoryImage(compressedImage!);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Center(child: pw.Image(image)),
      ),
    );
  }

  final DateTime now = DateTime.now();
  final DateFormat formatter = DateFormat('yyyyMMdd_HHmmss_ms');
  final String filename = formatter.format(now);
  String filePath = '';

  if (Platform.isAndroid) {
    filePath =
        '${Directory('/storage/emulated/0/Download').path}/$filename.pdf';
  } else {
    final directory = await getApplicationDocumentsDirectory();
    filePath = '${directory.path}/$filename.pdf';
  }

  final file = File(filePath);

  await file.writeAsBytes(await pdf.save());

  return filePath;
}

Future<XFile?> generateThumbnail(String videoPath) async {
  debugPrint('gen thumbnail image from: $videoPath');
  // final thumbnailImageData = await VideoThumbnail.thumbnailData(
  //   video: videoPath,
  //   maxWidth: 128, // Specify the desired thumbnail size
  //   quality: 100,
  // );

  final thumbnailImageData = await VideoCompress.getByteThumbnail(videoPath);

  if (thumbnailImageData != null) {
    // You can save the thumbnail to a file or use it directly
    final String filename = path.basenameWithoutExtension(videoPath);

    final DateTime now = DateTime.now();
    final DateFormat formatter = DateFormat('HHmmssms');
    final String subFileName = formatter.format(now);
    String filePath = '';

    if (Platform.isAndroid) {
      filePath =
          '${Directory('/storage/emulated/0/Download/temp').path}/vThumlImg_${filename}_$subFileName.png';

      Directory newDirectory = Directory('/storage/emulated/0/Download/temp');
      await newDirectory.create(recursive: true);
    } else {
      final directory = await getApplicationDocumentsDirectory();
      Directory newDirectory = Directory('${directory.path}/temp');
      await newDirectory.create(recursive: true);

      filePath = '${directory.path}/temp/${filename}_$subFileName.jpg';
    }

    final file = File(filePath);
    await file.writeAsBytes(thumbnailImageData);

    return XFile.fromData(file.readAsBytesSync(),
        length: file.lengthSync(), path: filePath);
  }

  return null;
}

Future<void> clearTempFiles(List<XFile> files) async {
  if (files.isNotEmpty) {
    for (var file in files) {
      File fileData = File(file.path);
      if (file.name.contains("vThumlImg_") && fileData.existsSync()) {
        await fileData.delete();
      }
    }
  }
}

String randomString({int length = 6}) {
  final random = Random();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';

  String randomString = String.fromCharCodes(Iterable.generate(
      length, (_) => chars.codeUnitAt(random.nextInt(chars.length))));

  return randomString;
}

Future<XFile?> compressVideo(String videoPath) async {
  MediaInfo? compressedVideoInfo = await VideoCompress.compressVideo(
    videoPath,
    quality: VideoQuality.MediumQuality, // Adjust quality as needed
    deleteOrigin:
        false, // Set to true to delete the original video after compression
  );

  if (compressedVideoInfo != null) {
    return XFile.fromData(compressedVideoInfo.file!.readAsBytesSync(),
        length: compressedVideoInfo.filesize, path: compressedVideoInfo.path);
  }

  return null;
}

//save data local
Future<void> saveData(Map<String, dynamic> data) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/data.json');
  await file.writeAsString(jsonEncode(data));
}

Future<Map<String, dynamic>?> loadData() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/data.json');
    final contents = await file.readAsString();
    return jsonDecode(contents);
  } catch (e) {
    return null;
  }
}
