import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

enum NotifyType {
  success,
  warning,
  error,
}

void notify(BuildContext context, String message, NotifyType type) {
  var mapTypes = <NotifyType, Color>{
    NotifyType.success: Colors.blue,
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
