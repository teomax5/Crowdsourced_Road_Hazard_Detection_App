import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {

  static const String apiUrl = "http://10.41.132.198:8000/detect";

  static Future<Map<String, dynamic>> detectHazard(File imageFile) async {

    var request = http.MultipartRequest(
      'POST',
      Uri.parse(apiUrl),
    );

    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    var response = await request.send();

    var responseData = await response.stream.bytesToString();

    return jsonDecode(responseData);
  }
}