import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:make_pdf/utils.dart';

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
  List<XFile> pickedFiles = [];
  List<XFile> images = [];
  List<XFile> videos = [];
  List<String> fileUrls = [];

  bool isProcessing = false;
  bool isLoading = false;

  Future<void> _handlePickedFiles() async {
    fileUrls = [];

    if (images.isEmpty && videos.isEmpty) {
      notify(context, "Chưa chọn hình ảnh hoặc video!", NotifyType.warning);
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

    List<String> filePaths = [];
    String mimeType = 'application/pdf';

    if (images.isNotEmpty) {
      filePaths.add(await makePdfFromImages(images));
    } else {
      for (var file in videos) {
        filePaths.add(file.path);
      }
      mimeType = 'video/mp4';
    }

    // Upload the PDF file
    try {
      // Get the access token
      final accessToken = await getAccessToken();

      for (String filePath in filePaths) {
        String fileUrl =
            await uploadFileToDrive(accessToken, filePath, mimeType: mimeType);
        fileUrls.add(fileUrl);
      }
    } catch (ex) {
      if (mounted) {
        notify(context, ex.toString().replaceAll('Exception: ', ''),
            NotifyType.error);

        isProcessing = false;
        setState(() {
          isLoading = false;
        });
        return;
      }
    } finally {
      await googleAccountSignOut();

      if (videos.isNotEmpty) {
        await clearTempFiles(pickedFiles);
      }
    }

    if (fileUrls.isEmpty) {
      if (mounted) {
        notify(context, "Tải file lên Google Drive không thành công.",
            NotifyType.error);
      }
    } else {
      if (mounted) {
        notify(context, "Đã tải file pdf lên Google Drive ở chế độ công khai.",
            NotifyType.success);
      }
    }

    isProcessing = false;
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _pickImages() async {
    if (videos.isNotEmpty) {
      await clearTempFiles(pickedFiles);
      videos = [];
    }

    images = [];
    // final result = await FilePicker.platform
    //     .pickFiles(type: FileType.image, allowMultiple: true);
    //
    // if (result != null) {
    //   images = result.files;
    //   pickedFiles = images;
    //   setState(() {});
    // }

    final ImagePicker picker = ImagePicker();
    images = await picker.pickMultiImage();
    pickedFiles = images;
    setState(() {});
  }

  Future<void> _pickVideo() async {
    if (videos.isNotEmpty) {
      await clearTempFiles(pickedFiles);
      images = [];
    }

    // final result = await FilePicker.platform
    //     .pickFiles(type: FileType.video, allowMultiple: true);
    // videos = [];
    // pickedFiles.clear();
    //
    // if (result != null) {
    //   videos = result.files;
    //   for (var vi in videos) {
    //     PlatformFile? thumbnailImage = await generateThumbnail(vi.path!);
    //     if (thumbnailImage != null) {
    //       pickedFiles.add(thumbnailImage);
    //     }
    //   }
    //
    //   setState(() {});
    // }

    final ImagePicker picker = ImagePicker();
    videos = await picker.pickMultipleMedia();
    pickedFiles.clear();
    for (var vi in videos) {
      var thumbnailImage = await generateThumbnail(vi.path);
      if (thumbnailImage != null) {
        pickedFiles.add(thumbnailImage);
      }
    }
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
                        itemCount: pickedFiles.length,
                        itemBuilder: (ctx, index) {
                          return SizedBox(
                            height: MediaQuery.of(context).size.height,
                            width: MediaQuery.of(context).size.width,
                            child: Image.file(
                              File(pickedFiles[index].path!),
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
                    child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: fileUrls.length,
                        itemBuilder: (ctx, idx) {
                          return GestureDetector(
                            onTap: () async {
                              Clipboard.setData(
                                  ClipboardData(text: fileUrls[idx]));
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
                                fileUrls[idx],
                                overflow: TextOverflow.clip,
                                style: const TextStyle(
                                    decoration: TextDecoration.underline,
                                    color: Colors.blue),
                              ),
                            ),
                          );
                        }),
                  ),
                ],
              ),
              Flexible(
                  flex: 1,
                  child: Row(
                    children: [
                      Container(
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
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 16.0),
                        // Set top and left margins
                        child: OutlinedButton(
                          onPressed: _pickVideo,
                          style: ButtonStyle(
                            side: WidgetStateProperty.all(const BorderSide(
                              color: Colors.redAccent,
                              width: 2.0,
                            )),
                          ),
                          child: const Text("Chọn video"),
                        ),
                      ),
                    ],
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
