import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'PDF Maker'),
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

  void notify(String message, NotifyType type){
    var mapTypes = <NotifyType,Color>{
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
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.all(Radius.circular(10))),
                  child:  Text(
                    message,
                    style: TextStyle(
                        color: mapTypes[type],
                        fontSize: 24.0,
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
      final GoogleSignInAccount? googleSignInAccount = await _googleSignIn.signIn();
      final GoogleSignInAuthentication googleSignInAuthentication =
      await googleSignInAccount!.authentication;
      return googleSignInAuthentication.accessToken;
    } catch (error) {
      print('Error signing in: $error');
      return null;
    }
  }

  Future<void> uploadPDF(String accessToken, String filePath) async {
    // final authHeaders = {
    //   'Authorization': 'Bearer $accessToken',
    //   'Content-Type': 'application/json',
    // };
    //
    // final client = http.Client();
    //
    // File file = File(filePath);
    // String filename = basename(file.path);
    //
    // // Create a file metadata object
    // final fileMetadata = drive.File()
    //   ..name = filename // Set the desired filename
    //   ..mimeType = 'application/pdf';
    //
    // // Create a multipart request
    // final request = http.MultipartRequest(
    //   'POST',
    //   Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart'),
    // );
    //
    // // Add headers
    // request.headers.addAll(authHeaders);
    //
    // // Add file metadata as JSON
    // // print('meta:  ${fileMetadata.toJson()}');
    // print('meta:  ${fileMetadata.toJson().toString()}');
    // request.files.add(http.MultipartFile.fromString(
    //   'metadata',
    //   fileMetadata.toJson().toString(),
    //   contentType: MediaType('application', 'json'),
    // ));
    //
    // // Add the PDF file content
    // request.files.add(await http.MultipartFile.fromPath(
    //   'media',
    //   filePath,
    // ));
    // print('added file');
    //
    // // Send the request
    // final response = await request.send();
    // print('response: ${response.toString()}');
    //
    // // Handle the response
    // if (response.statusCode == 200) {
    //   print('PDF uploaded successfully.');
    // } else {
    //   print('Error uploading PDF: ${response.reasonPhrase}');
    // }
    //
    // client.close();

    File file = File(filePath);
    String filename = basename(file.path);

    var res = await http.post(
      Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=media'),
      body: file.readAsBytesSync(),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json'
      },
    );
    if (res.statusCode == 200) {
      print('PDF uploaded successfully.');
      //return res.body;
    } else {
      Map json = jsonDecode(res.body);
      throw ('${json['error']['message']}');
    }

    // await _googleSignIn.signOut();
  }

  Future<void> _generatePdf() async {
    if (images.isEmpty) {
      notify("Chưa chọn hình ảnh!", NotifyType.ERROR);
      return;
    }

    final pdf = pw.Document();

    for (XFile file in images) {
      // print("file: ${file.path}");

      final image = pw.MemoryImage(
        File(file.path).readAsBytesSync(),
      );

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(child: pw.Image(image)),
        ),
      );
    }

    final DateTime now = DateTime.now();
    final DateFormat formatter = DateFormat('yyyy-MM-dd_HH-mm-ss_ms');
    final String filename = formatter.format(now);
    final String filePath = '${Directory('/storage/emulated/0/Download').path}/$filename.pdf';
    final file =
        File(filePath);
    print("result: ${filePath}");
    await file.writeAsBytes(await pdf.save());

    // Get the access token
    final accessToken = await getAccessToken();

    if (accessToken != null) {
      // Upload the PDF file
      await uploadPDF(accessToken, filePath);
    }

    notify("Tạo file pdf thành công.", NotifyType.SUCCESS);
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              flex: 10,
              child: Container(
                margin: const EdgeInsets.only(
                    top: 16.0, left: 16.0, right: 16.0, bottom: 16),
                // Set top and left margins
                child: GridView.builder(
                    itemCount: images.length,
                    itemBuilder: (ctx, index) {
                      return SizedBox(
                        height: MediaQuery.of(context).size.height,
                        width: MediaQuery.of(context).size.width,
                        child: Image.file(File(images[index].path), fit: BoxFit.contain,),
                      );
                    },
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10
                        )),
              )),
          Flexible(
              flex: 1,
              child: Container(
                margin: const EdgeInsets.only(left: 16.0),
                // Set top and left margins
                child: OutlinedButton(
                  onPressed: _pickImages,
                  style: ButtonStyle(
                    side: MaterialStateProperty.all(const BorderSide(
                      color: Colors.blue,
                      width: 1.0,
                    )),
                  ),
                  child: const Text("Chọn hình ảnh"),
                ),
              ))
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _generatePdf,
        tooltip: 'Tạo file pdf',
        child: const Icon(Icons.settings),
      ),
    );
  }
}
