import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:make_pdf/utils.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:video_player/video_player.dart';

import 'google.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PDF Maker App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: MyHomePage(title: 'Submit homework'),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<XFile> images = [];
  XFile? video = null;
  String fileUrl = '';
  bool isProcessing = false;
  bool isLoading = false;

  // VideoPlayerController? _controller;

  // void _initializeVideoPlayer(String path) {
  //   _controller = VideoPlayerController.file(File(path));
  //   setState(() {});
  // }

  // @override
  // void dispose() {
  //   _controller?.dispose();
  //   super.dispose();
  // }

  Future<void> _handlePickedFiles() async {
    if (images.isEmpty && video == null) {
      notify(context, "Chưa chọn hình ảnh hoặc video!", NotifyType.error);
      return;
    }

    if (isProcessing) {
      Fluttertoast.showToast(
          msg: "Đang xử lý tác vụ khác!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 2,
          backgroundColor: Colors.white,
          textColor: Colors.orange,
          fontSize: 16.0);
      return;
    }
    isProcessing = true;
    setState(() {
      isLoading = true;
    });

    // Get the access token
    final accessToken = await getAccessToken();

    if (accessToken == null) {
      if (mounted) {
        notify(context, "Bạn chưa cấp quyền tải file lên Google Drive",
            NotifyType.warning);
      }

      isProcessing = false;
      setState(() {
        isLoading = false;
      });
      return;
    }

    String filePath = '';

    if (images.isNotEmpty) {
      final pdf = pw.Document();

      for (XFile file in images) {
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
      final DateFormat formatter = DateFormat('yyyy-MM-dd_HH-mm-ss_ms');
      final String filename = formatter.format(now);
      filePath =
          '${Directory('/storage/emulated/0/Download').path}/$filename.pdf';
      final file = File(filePath);

      await file.writeAsBytes(await pdf.save());
    } else {
      filePath = video!.path;
    }

    // Upload the PDF file
    fileUrl = await uploadFileToDrive(accessToken, filePath);

    if (fileUrl.isEmpty) {
      if (mounted) {
        notify(context, "Tải file lên Google Drive không thành công.",
            NotifyType.error);
      }
    } else {
      if (mounted) {
        notify(
            context,
            "Đã tải file pdf lên Google Drive ở chế độ công khai.",
            NotifyType.success);
      }
    }

    isProcessing = false;
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    images = await picker.pickMultiImage();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  flex: 10,
                  child: Container(
                    margin: const EdgeInsets.only(
                        top: 16, left: 16, right: 16, bottom: 16),
                    // Set top and left margins
                    child: GridView.builder(
                        itemCount: images.length,
                        itemBuilder: (ctx, index) {
                          return SizedBox(
                            height: MediaQuery.of(context).size.height,
                            width: MediaQuery.of(context).size.width,
                            child: Image.file(
                              File(images[index].path),
                              fit: BoxFit.contain,
                            ),
                          );
                        },
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10)),
                  )),
              Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(
                        top: 8, left: 16, right: 4, bottom: 8),
                    child: const Text(
                      "File URL: ",
                    ),
                  ),
                  Flexible(
                    child: GestureDetector(
                      onTap: () async {
                        Clipboard.setData(ClipboardData(text: fileUrl));
                        Fluttertoast.showToast(
                            msg: "Đã sao chép vào bộ nhớ",
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            timeInSecForIosWeb: 2,
                            backgroundColor: Colors.white,
                            textColor: Colors.cyan,
                            fontSize: 16.0);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(
                            top: 8, left: 4, right: 16, bottom: 8),
                        child: Text(
                          fileUrl,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                              decoration: TextDecoration.underline,
                              color: Colors.blue),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Flexible(
                  flex: 1,
                  child: Container(
                    margin: const EdgeInsets.only(left: 16.0),
                    // Set top and left margins
                    child: OutlinedButton(
                      onPressed: _pickImages,
                      style: ButtonStyle(
                        side: WidgetStateProperty.all(const BorderSide(
                          color: Colors.lightBlueAccent,
                          width: 2.0,
                        )),
                      ),
                      child: const Text("Chọn hình ảnh"),
                    ),
                  ))
            ],
          ),
          if (isLoading) const Center(child: CircularProgressIndicator())
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: !isProcessing ? _handlePickedFiles : null,
        tooltip: 'Tạo file pdf',
        child: const Icon(Icons.upload_file),
      ),
    );
  }
}
