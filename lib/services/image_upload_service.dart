import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

class ImageUploadService {
  static const String _imgbbApiKey = 'af5ca570bb7a1562dae8ef0c7f01a585';
  static const String _imgbbUrl = 'https://api.imgbb.com/1/upload';

  final Dio _dio = Dio();

  Future<String?> uploadImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final fileName = imageFile.path.split('/').last;

      final response = await _dio.post(
        _imgbbUrl,
        data: {
          'key': _imgbbApiKey,
          'image': base64Image,
          'name': fileName,
        },
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return data['data']['url'] as String?;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
