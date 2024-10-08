import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:make_pdf/utils.dart';
import 'package:path/path.dart' as path;

import 'preview_image.dart';
import 'google.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, // Allow only portrait up orientation
  ]).then((_) {
    runApp(const MyApp());
  });
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
        body: MyHomePage(title: 'Homework'),
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

const String DRIVE = 'drive';

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
  late String drive = '';
  late String rootDrive = '';

  // text field controller
  final _textController = TextEditingController();
  final _driveController = TextEditingController();
  final _rootDriveController = TextEditingController();

  bool isProcessing = false;
  bool isLoading = false;

  Future<void> _loadData() async {
    var data = await loadData();
    debugPrint('data: $data');
    if (data != null) {
      setState(() {
        rootDrive = data[DRIVE];
        _rootDriveController.text = rootDrive;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  @override
  void dispose() {
    _textController.dispose();
    _driveController.dispose();
    _rootDriveController.dispose();
    super.dispose();
  }

  Future<void> _handlePickedFiles() async {
    fileUrls = [];

    if (images.isEmpty && videos.isEmpty) {
      notify(context, "Chưa chọn hình ảnh hoặc video!", NotifyType.warning);
      if (mounted) {
        FocusScope.of(context).requestFocus(FocusNode());
      }
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

      if (mounted) {
        FocusScope.of(context).requestFocus(FocusNode());
      }
      return;
    }
    setState(() {
      isProcessing = true;
      isLoading = true;
    });

    List<String> filePaths = [];

    if (images.isNotEmpty) {
      filePaths.add(await makePdfFromImages(images));
    }

    if (videos.isNotEmpty) {
      for (var file in videos) {
        filePaths.add(file.path);
      }
    }

    // Upload the PDF file
    try {
      // Get the access token
      final accessToken = await getAccessToken();
      String? driveId = await createNewDrive(accessToken, drive, rootDrive);
      Map<String, String> videoMimeTypes = {
        '.mp4': 'video/mp4',
        '.mov': 'video/quicktime',
        '.wmv': 'video/x-ms-wmv',
      };

      for (String filePath in filePaths) {
        String ext = path.extension(filePath);
        await uploadFileToDrive(accessToken, filePath, filename, driveId,
            mimeType: ext == '.pdf'
                ? 'application/pdf'
                : (videoMimeTypes[ext] ?? 'video/mp4'));
      }
      fileUrls.add('https://drive.google.com/drive/u/0/folders/$driveId');

      //save drive name in local storage
      var data = await loadData();

      if (data == null && rootDrive.isNotEmpty) {
        data = <String, String>{DRIVE: rootDrive};
        await saveData(data);
      } else if (data != null && data[DRIVE] != rootDrive) {
        data[DRIVE] = rootDrive;
        await saveData(data);
      }

      _clearAllFiles();
    } catch (ex) {
      debugPrint(ex.toString());
      String message = ex.toString().replaceAll('Exception: ', '');

      if (mounted) {
        if (message.contains('[KKException]')) {
          notify(context, message.replaceAll('[KKException]', ''),
              NotifyType.error);
        } else {
          notify(context, 'Kiểm tra kết nối mạng và vui lòng thử lại...',
              NotifyType.error);
        }
      }
      setState(() {
        isProcessing = false;
        isLoading = false;
      });

      return;
    } finally {
      await googleAccountSignOut();

      // if (videos.isNotEmpty) {
      //   await clearTempFiles(pickedFiles);
      // }

      if (filePaths[0].contains('.pdf')) {
        File fileData = File(filePaths[0]);
        await fileData.delete();
      }

      if (mounted) {
        FocusScope.of(context).requestFocus(FocusNode());
      }
    }

    if (fileUrls.isEmpty) {
      if (mounted) {
        notify(context, "Tải file lên Google Drive không thành công.",
            NotifyType.error);
      }
    } else {
      setState(() {
        filename = '';
        drive = '';
      });

      //clear textField
      _textController.clear();
      _driveController.clear();

      if (mounted) {
        notify(context, "Đã tải file pdf lên Google Drive ở chế độ công khai.",
            NotifyType.success);
      }
    }

    setState(() {
      isProcessing = false;
      isLoading = false;
    });
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    var newImages = await picker.pickMultiImage();
    images.addAll(newImages);
    pickedFiles.addAll(newImages);
    setState(() {});
  }

  Future<void> _pickVideos() async {
    final ImagePicker picker = ImagePicker();
    var newVideos = await picker.pickMultipleMedia();
    videos.addAll(newVideos);

    for (var vi in newVideos) {
      if (path.extension(vi.path) != '.mp4' &&
          path.extension(vi.path) != '.mov') {
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

  // take pictures in person
  Future<void> _takePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      pickedFiles.add(photo);
      images.add(photo);
      setState(() {});
    }
  }

  Future<void> _clearAllFiles() async {
    if (videos.isNotEmpty) {
      await clearTempFiles(pickedFiles);
    }
    videos.clear();
    images.clear();
    pickedFiles.clear();

    setState(() {});
  }

  void showImagePopup(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ImagePopup(imageUrl: imageUrl);
      },
    );
  }

  Future<void> removeFile(int index) async {
    XFile file = pickedFiles.removeAt(index);

    if (images.isNotEmpty) {
      for (int i = 0; i < images.length; i++) {
        if (file.name == images[i].name) {
          images.removeAt(i);
          break;
        }
      }
    }

    if (videos.isNotEmpty) {
      for (int i = 0; i < videos.length; i++) {
        if (file.name.contains(videos[i].name.split(".")[0])) {
          videos.removeAt(i);

          File fileData = File(file.path);
          await fileData.delete();
          break;
        }
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        toolbarHeight: 40,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  flex: 8,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    // Set top and left margins
                    child: GridView.builder(
                        itemCount: pickedFiles.length,
                        itemBuilder: (ctx, index) {
                          return GestureDetector(
                              onTap: () {
                                showImagePopup(
                                    context, pickedFiles[index].path);
                              },
                              child: Stack(children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height,
                                  width: MediaQuery.of(context).size.width,
                                  child: Image.file(
                                    File(pickedFiles[index].path),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                Positioned(
                                  top: -10,
                                  right: -10,
                                  child: IconButton(
                                    onPressed: () {
                                      removeFile(index);
                                    },
                                    icon: const Icon(
                                      Icons.close_sharp,
                                      color: Colors.red,
                                    ),
                                  ),
                                )
                              ]));
                        },
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10)),
                  )),
              Flexible(
                  child: Row(
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 8, top: 8),
                    // Set top and left margins
                    child: SizedBox(
                      height: 40,
                      width: 40,
                      child: IconButton(
                        icon: const Icon(
                          Icons.photo_camera,
                          color: Colors.orange,
                        ),
                        onPressed: _takePicture,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    // Set top and left margins
                    child: SizedBox(
                      height: 40,
                      width: 40,
                      child: IconButton(
                        icon: const Icon(
                          Icons.image,
                          color: Colors.lightGreen,
                        ),
                        onPressed: _pickImages,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    // Set top and left margins
                    child: SizedBox(
                      height: 40,
                      width: 40,
                      child: IconButton(
                        icon: const Icon(
                          Icons.video_camera_back,
                          color: Colors.redAccent,
                        ),
                        onPressed: _pickVideos,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    // Set top and left margins
                    child: SizedBox(
                      height: 40,
                      width: 40,
                      child: IconButton(
                        icon: const Icon(
                          Icons.delete_sweep,
                          color: Colors.grey,
                        ),
                        onPressed: _clearAllFiles,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Container(
                        margin: const EdgeInsets.only(
                            left: 8, bottom: 4, right: 12),
                        height: 40,
                        // width: MediaQuery.of(context).size.width / 1.9,
                        child: TextField(
                          controller: _textController,
                          decoration: const InputDecoration(
                            hintText: 'Nhập tên file',
                            hintStyle: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w300),
                            contentPadding: EdgeInsets.only(bottom: 0),
                          ),
                          autofocus: false,
                          onTapOutside: (e) {
                            FocusScope.of(context).unfocus();
                          },
                          onChanged: (text) {
                            setState(() {
                              filename = text;
                            });
                          },
                        )),
                  )
                ],
              )),
              Row(
                children: [
                  Container(
                    width: 80,
                    margin: const EdgeInsets.only(
                        top: 0, left: 8, right: 0, bottom: 0),
                    child: const Text("Thư mục gốc: ",
                        style: TextStyle(fontSize: 12.5)),
                  ),
                  Flexible(
                    child: Container(
                        height: 40,
                        margin: const EdgeInsets.only(
                            left: 8, bottom: 8, right: 90),
                        // width: MediaQuery.of(context).size.width / 1.9,
                        child: TextField(
                          controller: _rootDriveController,
                          decoration: const InputDecoration(
                            hintText: 'Nhập thư mục gốc',
                            hintStyle: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w300),
                            contentPadding: EdgeInsets.only(top: 0),
                          ),
                          autofocus: false,
                          onTapOutside: (e) {
                            FocusScope.of(context).unfocus();
                          },
                          onChanged: (text) {
                            setState(() {
                              rootDrive = text;
                            });
                          },
                        )),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 80,
                    margin: const EdgeInsets.only(
                        top: 0, left: 8, right: 0, bottom: 0),
                    child: const Text("Thư mục nộp: ",
                        style: TextStyle(fontSize: 12.5)),
                  ),
                  Flexible(
                    child: Container(
                        height: 40,
                        margin: const EdgeInsets.only(
                            left: 8, bottom: 8, right: 90),
                        // width: MediaQuery.of(context).size.width / 1.9,
                        child: TextField(
                          controller: _driveController,
                          decoration: const InputDecoration(
                            hintText: 'Nhập thư mục lưu bài tập',
                            hintStyle: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w300),
                            contentPadding: EdgeInsets.only(top: 0),
                          ),
                          autofocus: false,
                          onTapOutside: (e) {
                            FocusScope.of(context).unfocus();
                          },
                          onChanged: (text) {
                            setState(() {
                              drive = text;
                            });
                          },
                        )),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    height: 50,
                    width: 80,
                    margin: const EdgeInsets.only(
                        top: 8, left: 8, right: 0, bottom: 0),
                    alignment: Alignment.topLeft,
                    child: const Text("Kết quả: ",
                        style: TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.w500)),
                  ),
                  Flexible(
                    child: Container(
                      height: 50,
                      margin: const EdgeInsets.only(left: 4, right: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.blueGrey, // Border color
                          width: 1.2, // Border width
                        ),
                        borderRadius: BorderRadius.circular(
                            10.0), // Optional: Add rounded corners
                      ),
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
                                    textColor: Colors.blueAccent,
                                    fontSize: 16.0);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(
                                    top: 8, left: 4, right: 12, bottom: 8),
                                child: Text(
                                  '${idx + 1}. ${fileUrls[idx]}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      // decoration: TextDecoration.underline,
                                      color: Colors.blue),
                                ),
                              ),
                            );
                          }),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 90.0,
            right: 20.0, // Adjust these values to move the FAB
            child: FloatingActionButton(
              onPressed: !isProcessing ? _handlePickedFiles : null,
              tooltip: 'Upload files',
              child: const Icon(
                Icons.upload,
                color: Color(0xFF5279B7),
              ),
            ),
          ),
          if (isLoading) const Center(child: CircularProgressIndicator())
        ],
      ),
    );
  }
}
