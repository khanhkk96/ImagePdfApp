import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import 'package:make_pdf/utils.dart';
import 'package:path/path.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: [
    'https://www.googleapis.com/auth/drive.file',
  ],
);

Future<String?> getAccessToken() async {
  try {
    final GoogleSignInAccount? googleSignInAccount =
        await _googleSignIn.signIn();
    final GoogleSignInAuthentication googleSignInAuthentication =
        await googleSignInAccount!.authentication;
    return googleSignInAuthentication.accessToken;
  } catch (error) {
    debugPrint('Error signing in: $error');
    await _googleSignIn.signOut();
    return null;
  }
}

Future<void> googleAccountSignOut() async {
  await _googleSignIn.signOut();
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

  try {
    final response = await client.post(
      Uri.parse(
          'https://www.googleapis.com/drive/v3/files/$fileId/permissions'),
      headers: headers,
      body: jsonEncode(permission.toJson()),
    );

    if (response.statusCode == 200) {
      // setState(() {});
      debugPrint('Permission granted successfully.');
    } else {
      debugPrint('Error granting permission: ${response.reasonPhrase}');
    }
  } catch (e) {
    debugPrint('Error granting permission: $e');
  } finally {
    client.close();
  }
}

Future<String> uploadFileToDrive(
    String? accessToken, String filePath, String uploadFilename,
    {String mimeType = 'application/pdf'}) async {
  // Get the access token
  // final accessToken = await getAccessToken();

  if (accessToken == null) {
    throw Exception('[KKException]Bạn chưa cấp quyền tải file lên Google Drive');
  }

  final authHeaders = {
    'Authorization': 'Bearer $accessToken',
  };

  final client = http.Client();

  File file = File(filePath);
  String subFileName = randomString();
  String filename = '';

  if(uploadFilename.isEmpty){
    filename =
    '${basenameWithoutExtension(file.path)}_$subFileName${extension(file.path)}';
  }
  else{
    final DateTime now = DateTime.now();
    final DateFormat formatter = DateFormat('yyyyMMdd_HHmm');
    final String timeString = formatter.format(now);
    filename =
    '${uploadFilename}_${timeString}_$subFileName${extension(file.path)}';
  }

  // Create a file metadata object
  final fileMetadata = drive.File()
    ..name = filename // Set the desired filename
    ..mimeType = mimeType;

  // Create a multipart request
  final request = http.MultipartRequest(
    'POST',
    Uri.parse(
        'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart'),
  );

  // Add headers
  request.headers.addAll(authHeaders);

  // Add file metadata as JSON
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

  // Send the request
  final response = await request.send();

  String fileUrl = '';

  // Handle the response
  if (response.statusCode == 200) {
    debugPrint('A file - ${basename(file.path)} has been uploaded successfully!');
    final responseBody = await response.stream.bytesToString();
    final jsonResponse = jsonDecode(responseBody);
    final fileId = jsonResponse['id'] as String;

    fileUrl = 'https://drive.google.com/file/d/$fileId/view';

    //share permission
    await shareFileWithUser(accessToken, fileId);
  } else {
    await file.delete();
    debugPrint('Error uploading file: ${response.reasonPhrase}');
  }

  client.close();

  return fileUrl;
}
