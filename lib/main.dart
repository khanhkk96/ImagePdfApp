import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:make_pdf/utils.dart';
import 'package:path/path.dart' as path;

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
  //display picked files
  List<XFile> pickedFiles = [];

  //picked images
  List<XFile> images = [];

  //picked videos
  List<XFile> videos = [];

  //uploaded file urls
  List<String> fileUrls = [];
  late String filename = '';
  final _textController = TextEditingController();

  bool isProcessing = false;
  bool isLoading = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

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
      debugPrint('filename inputed: ${filename}');

      for (String filePath in filePaths) {
        String fileUrl = await uploadFileToDrive(
            accessToken, filePath, filename,
            mimeType: mimeType);
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

      //clear textField
      _textController.clear();
      setState(() {
        filename = '';
      });
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

    final ImagePicker picker = ImagePicker();
    images = await picker.pickMultiImage();
    pickedFiles = images;
    setState(() {});
  }

  Future<void> _pickVideos() async {
    if (videos.isNotEmpty) {
      await clearTempFiles(pickedFiles);
      images = [];
    }

    final ImagePicker picker = ImagePicker();
    videos = await picker.pickMultipleMedia();
    pickedFiles.clear();

    for (var vi in videos) {
      if (path.extension(vi.path) != '.mp4') {
        videos = [];

        if (mounted) {
          notify(context, "Chỉ chọn video cần tải lên.", NotifyType.warning);
        }
        break;
      }
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
                    margin: const EdgeInsets.all(8),
                    // Set top and left margins
                    child: GridView.builder(
                        itemCount: pickedFiles.length,
                        itemBuilder: (ctx, index) {
                          return SizedBox(
                            height: MediaQuery.of(context).size.height,
                            width: MediaQuery.of(context).size.width,
                            child: Image.file(
                              File(pickedFiles[index].path),
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
                        top: 8, left: 8, right: 0, bottom: 8),
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
                                  top: 4, left: 4, right: 12, bottom: 4),
                              child: Text(
                                '${idx + 1}. ${fileUrls[idx]}',
                                overflow: TextOverflow.ellipsis,
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
                        margin: const EdgeInsets.only(left: 4.0),
                        // Set top and left margins
                        child: IconButton(
                            icon: const Icon(
                              Icons.image,
                              color: Colors.lightGreen,
                            ),
                            onPressed: _pickImages,
                            style: ElevatedButton.styleFrom(
                                side: const BorderSide(
                              color: Colors.greenAccent,
                              width: 2.0,
                            ))),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 0),
                        // Set top and left margins
                        child: IconButton(
                            icon: const Icon(
                              Icons.video_camera_back,
                              color: Colors.redAccent,
                            ),
                            onPressed: _pickVideos,
                            style: ElevatedButton.styleFrom(
                                side: const BorderSide(
                                  color: Colors.red,
                                  width: 2.0,
                                ),
                                maximumSize: const Size(60, 50))),
                      ),
                      Container(
                          margin: const EdgeInsets.only(left: 8),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height,
                            width: MediaQuery.of(context).size.width / 2,
                            child: TextField(
                              controller: _textController,
                              decoration: const InputDecoration(
                                  hintText: 'Nhập tên file',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  contentPadding: EdgeInsets.only(top: 20)),
                              autofocus: false,
                              onTapOutside: (e) {
                                FocusScope.of(context).unfocus();
                              },
                              onChanged: (text) {
                                filename = text;
                                setState(() {});
                              },
                            ),
                          ))
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
        child: const Icon(Icons.upload),
      ),
    );
  }
}
