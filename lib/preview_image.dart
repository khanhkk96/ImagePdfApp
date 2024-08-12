import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class FullScreenImage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Image'),
      ),
      body: PhotoView(
        imageProvider: FileImage(File(imageUrl)),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2,
      ),
    );
  }
}

class ImagePopup extends StatelessWidget {
  final String imageUrl;

  const ImagePopup({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 360, // Adjust width as needed
        height: 500, // Adjust height as needed
        child: Image.file(
          File(imageUrl),
          fit: BoxFit.fitWidth, // Adjust fit as needed
        ),
      ),
    );
  }
}
