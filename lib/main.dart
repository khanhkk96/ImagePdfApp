import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

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

class _MyHomePageState extends State<MyHomePage> {
  List<XFile> images = [];

  Future<void> _generatePdf() async {
    if (images.isEmpty) {
      showDialog(
          context: context,
          builder: (context) {
            return Center(
              child: Wrap(children: [
                Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(10))),
                    child: const Text(
                      "Chưa chọn hình ảnh!",
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 24.0,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none),
                    )),
              ]),
            );
          });
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

    // String filename = DateTime.now().millisecondsSinceEpoch.toString();
    final DateTime now = DateTime.now();
    final DateFormat formatter = DateFormat('yyyy-MM-dd_HH-mm-ss');
    final String filename = formatter.format(now);
    final file =
        File('${Directory('/storage/emulated/0/Download').path}/$filename.pdf');
    // print("result: ${file.path}");
    await file.writeAsBytes(await pdf.save());

    showDialog(
        context: context,
        builder: (context) {
          return Center(
            child: Wrap(children: [
              Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.all(Radius.circular(10))),
                  child: const Text(
                    "Tạo file pdf thành công.",
                    style: TextStyle(
                        color: Colors.blue,
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none),
                  )),
            ]),
          );
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
      // body: Center(
      //   child: GridView.builder(
      //       itemCount: images.length,
      //       itemBuilder: (ctx,index) {
      //         return Image.file(File(images[index].path));
      //       }, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      //     crossAxisCount: 1,
      //     mainAxisSpacing: 10,
      //     crossAxisSpacing: 5,
      //     childAspectRatio: 1.0
      //   ))
      // ),
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
                  child: const Text("Chọn hình"),
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
