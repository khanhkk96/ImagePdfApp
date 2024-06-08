import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart';

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

enum NotifyType {
  SUCCESS,
  WARNING,
  ERROR,
}

class _MyHomePageState extends State<MyHomePage> {
  List<XFile> images = [];
  String fileUrl = '';
  bool isProcessing = false;
  bool isLoading =false;

  void notify(String message, NotifyType type) {
    var mapTypes = <NotifyType, Color>{
      NotifyType.SUCCESS: Colors.blue,
      NotifyType.WARNING: Colors.orange,
      NotifyType.ERROR: Colors.red,
    };

    showDialog(
        context: this.context,
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

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  Future<String?> getAccessToken() async {
    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleSignInAccount =
          await _googleSignIn.signIn();
      final GoogleSignInAuthentication googleSignInAuthentication =
          await googleSignInAccount!.authentication;
      return googleSignInAuthentication.accessToken;
    } catch (error) {
      print('Error signing in: $error');
      return null;
    }
  }

  Future<void> shareFileWithUser(String accessToken, String fileId,
      {String? userEmail}) async {
    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };

    final client = http.Client();

    // Create a permission object
    final permission = drive.Permission()
      ..type = 'anyone'
      ..role = 'writer';
    // ..emailAddress = userEmail;

    try {
      final response = await client.post(
        Uri.parse(
            'https://www.googleapis.com/drive/v3/files/$fileId/permissions'),
        headers: headers,
        body: jsonEncode(permission.toJson()),
      );

      if (response.statusCode == 200) {
        setState(() {});
        print('Permission granted successfully.');
      } else {
        print('Error granting permission: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error granting permission: $e');
    } finally {
      client.close();
    }
  }

  Future<void> uploadPDF(String accessToken, String filePath) async {
    fileUrl = '';
    setState(() {});
    final authHeaders = {
      'Authorization': 'Bearer $accessToken',
      // 'Content-Type': 'application/json',
    };

    final client = http.Client();

    File file = File(filePath);
    String filename = basename(file.path);

    // Create a file metadata object
    final fileMetadata = drive.File()
      ..name = filename // Set the desired filename
      ..mimeType = 'application/pdf';

    // Create a multipart request
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
          'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart'),
    );

    // Add headers
    request.headers.addAll(authHeaders);

    // Add file metadata as JSON
    // print('meta:  ${fileMetadata.toJson().toString()}');
    request.files.add(http.MultipartFile.fromString(
      'metadata',
      jsonEncode(fileMetadata),
      contentType: MediaType('application', 'json'),
    ));

    // Add the PDF file content
    request.files.add(await http.MultipartFile.fromPath(
      'media',
      filePath,
      contentType: MediaType('application', 'pdf'),
    ));
    // print('added file: ${request}');

    // Send the request
    final response = await request.send();

    // Handle the response
    if (response.statusCode == 200) {
      print('PDF uploaded successfully!');
      final responseBody = await response.stream.bytesToString();
      final jsonResponse = jsonDecode(responseBody);
      final fileId = jsonResponse['id'] as String;
      // print('fileID: $jsonResponse');

      fileUrl = 'https://drive.google.com/file/d/$fileId/view';

      //share permission
      await shareFileWithUser(accessToken, fileId);

      notify("Đã tải file pdf lên Google Drive ở chế độ công khai.", NotifyType.SUCCESS);
    } else {
      notify("Tạo file pdf không thành công.", NotifyType.ERROR);
      await file.delete();
      print('Error uploading PDF: ${response.reasonPhrase}');
    }

    client.close();
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

  Future<void> _generatePdf() async {
    if (images.isEmpty) {
      notify("Chưa chọn hình ảnh!", NotifyType.ERROR);
      return;
    }

    if (isProcessing) {
      // notify("Đang xử lý tác vụ khác!", NotifyType.WARNING);
      Fluttertoast.showToast(
          msg: "Đang xử lý tác vụ khác!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 2,
          backgroundColor: Colors.white,
          textColor: Colors.orange,
          fontSize: 16.0
      );
      return;
    }
    isProcessing = true;
    setState(() { isLoading = true; });

    final pdf = pw.Document();

    for (XFile file in images) {
      // print("file: ${file.path}");

      //compress the quality of image
      var compressedImage = await compressImage(await file.readAsBytes());
      final image = pw.MemoryImage(
          compressedImage!
      );

      // final image = pw.MemoryImage(
      //   File(file.path).readAsBytesSync(),
      // );

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(child: pw.Image(image)),
        ),
      );
    }

    final DateTime now = DateTime.now();
    final DateFormat formatter = DateFormat('yyyy-MM-dd_HH-mm-ss_ms');
    final String filename = formatter.format(now);
    final String filePath =
        '${Directory('/storage/emulated/0/Download').path}/$filename.pdf';
    final file = File(filePath);
    // print("result: ${filePath}");
    await file.writeAsBytes(await pdf.save());

    // Get the access token
    final accessToken = await getAccessToken();

    if (accessToken != null) {
      // Upload the PDF file
      await uploadPDF(accessToken, filePath);
      isProcessing = false;
      setState(() { isLoading = false; });
    } else {
      notify(
          "Bạn chưa cấp quyền tải file lên Google Drive", NotifyType.WARNING);
      isProcessing = false;
      setState(() { isLoading = false; });
    }
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
                            fontSize: 16.0
                        );
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
                        side: MaterialStateProperty.all(const BorderSide(
                          color: Colors.lightBlueAccent,
                          width: 2.0,
                        )),
                      ),
                      child: const Text("Chọn hình ảnh"),
                    ),
                  ))
            ],
          ),
         if(isLoading) const Center(child: CircularProgressIndicator())
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: !isProcessing ? _generatePdf: null,
        tooltip: 'Tạo file pdf',
        child: const Icon(Icons.upload_file),
      ),
    );
  }
}
