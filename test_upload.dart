import 'dart:io';
import 'package:dio/dio.dart';

void main() async {
  try {
    print("Creating dummy file...");
    File dummy = File("dummy.txt");
    await dummy.writeAsString("Hello from Dart Test");

    print("Uploading to https://shazid.info/uploadLinkup.php...");
    final dio = Dio();
    FormData formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(dummy.path, filename: "dummy.txt"),
    });

    final response = await dio.post(
      "https://shazid.info/uploadLinkup.php",
      data: formData,
    );

    print("Server Response Status: ${response.statusCode}");
    print("Server Response Data: ${response.data}");
    
    await dummy.delete();
  } catch (e) {
    if (e is DioException) {
      print("Dio Error (toString): $e");
      print("Dio Error underneath: ${e.error}");
    } else {
      print("Other Error: $e");
    }
  }
}
