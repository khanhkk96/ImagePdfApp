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

// Helper class to handle authentication headers
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return http.Client().send(request..headers.addAll(_headers));
  }
}

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

Future<drive.File?> getGoogleDriveFileByName(
    String accessToken, String fileName,
    {String? parentId}) async {
  // Create a client for the Drive API
  final authHeaders = {'Authorization': 'Bearer $accessToken'};
  final client = GoogleAuthClient(authHeaders);

  // Build the Drive API service
  final driveApi = drive.DriveApi(client);

  // Search for the file/folder by name
  final fileList = await driveApi.files.list(
    q: "mimeType='application/vnd.google-apps.folder' and name='$fileName'",
    spaces: 'drive', // Search in "My Drive",
    driveId: parentId,
  );

  client.close();
  // Return the first matching file/folder (if found)
  debugPrint('fileList: ${fileList.toJson().toString()}');
  debugPrint('fileList length: ${fileList.files?.length.toString()}');

  if (fileList.files == null || fileList.files!.isEmpty) {
    return null;
  } else if (fileList.files!.length > 1) {
    throw Exception('[KKException]Có nhiều hơn 1 thư mục cùng tên');
  } else {
    return fileList.files!.first;
  }
}

Future<String> createNewDrive(
    String? accessToken, String? driveName, String? parentDrive) async {
  if (accessToken == null) {
    throw Exception(
        '[KKException]Bạn chưa cấp quyền tải file lên Google Drive');
  }

  final authHeaders = {
    'Authorization': 'Bearer $accessToken',
  };

  String? rootDriveId;

  if (parentDrive != null && parentDrive.isNotEmpty) {
    var existedDrive = await getGoogleDriveFileByName(accessToken, parentDrive);
    debugPrint('parent drive: ${existedDrive?.toJson().toString()}');

    if (existedDrive != null && existedDrive.id != null) {
      rootDriveId = existedDrive.id.toString();
    } else {
      final client = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(client);

      final folder = drive.File();
      folder.name = parentDrive;
      folder.mimeType = 'application/vnd.google-apps.folder';

      var driveData = await driveApi.files.create(folder);
      rootDriveId = driveData.id;
      client.close();
    }
  }

  if (driveName != null && driveName.isNotEmpty) {
    var existedDrive = await getGoogleDriveFileByName(accessToken, driveName);
    debugPrint('drive: ${existedDrive?.toJson().toString()}');

    if (existedDrive != null && existedDrive.id != null) {
      return existedDrive.id.toString();
    }
  }

  String subFileName = randomString(length: 3);
  final DateTime now = DateTime.now();
  final DateFormat formatter = DateFormat('yyyyMMdd');
  final String dateString = formatter.format(now);
  String ggDriveName = driveName == null || driveName.isEmpty
      ? '${dateString}_$subFileName'
      : driveName;
  // : '${driveName}_$subFileName';

  // Create a file metadata object
  final fileMetadata = drive.File()
    ..name = ggDriveName // Set the desired filename
    ..mimeType = 'application/vnd.google-apps.folder'
    ..parents = rootDriveId != null ? [rootDriveId] : [];

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

  // Send the request
  final response = await request.send();

  String driveId = '';

  // Handle the response
  if (response.statusCode == 200) {
    debugPrint('A drive - $driveName has been uploaded successfully!');
    final responseBody = await response.stream.bytesToString();
    final jsonResponse = jsonDecode(responseBody);
    final fileId = jsonResponse['id'] as String;
    driveId = fileId;

    //share permission
    await shareFileWithUser(accessToken, fileId);
  } else {
    debugPrint('Error uploading file: ${response.reasonPhrase}');
  }

  return driveId;
}

Future<String> uploadFileToDrive(String? accessToken, String filePath,
    String uploadFilename, String? driveId,
    {String mimeType = 'application/pdf'}) async {
  if (accessToken == null) {
    throw Exception(
        '[KKException]Bạn chưa cấp quyền tải file lên Google Drive');
  }

  final authHeaders = {
    'Authorization': 'Bearer $accessToken',
  };

  final client = http.Client();

  File file = File(filePath);
  String subFileName = randomString();
  String filename = '';

  if (uploadFilename.isEmpty) {
    filename =
        '${basenameWithoutExtension(file.path)}_$subFileName${extension(file.path)}';
  } else {
    final DateTime now = DateTime.now();
    final DateFormat formatter = DateFormat('yyyyMMdd_HHmm');
    final String timeString = formatter.format(now);
    filename =
        '${uploadFilename}_${timeString}_$subFileName${extension(file.path)}';
  }

  // Create a file metadata object
  final fileMetadata = drive.File()
    ..name = filename // Set the desired filename
    ..mimeType = mimeType
    ..parents = driveId != null ? [driveId] : [];

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
    debugPrint(
        'A file - ${basename(file.path)} has been uploaded successfully!');
    final responseBody = await response.stream.bytesToString();
    final jsonResponse = jsonDecode(responseBody);
    final fileId = jsonResponse['id'] as String;

    fileUrl = 'https://drive.google.com/file/d/$fileId/view';

    //share permission
    // await shareFileWithUser(accessToken, fileId);
  } else {
    await file.delete();
    debugPrint('Error uploading file: ${response.reasonPhrase}');
  }

  client.close();

  return fileUrl;
}
