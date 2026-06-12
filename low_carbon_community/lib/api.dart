// lib/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'authService.dart';

class ApiClient {
  /// โดเมน/เบส URL ของหลังบ้าน
  static const String baseUrl = 'https://student.crru.ac.th/651463011/LowCarbonAPI/api';

  /// ไคลเอนต์ HTTP ส่วนกลาง
  static final http.Client httpClient = http.Client();

  /// timeout เริ่มต้นของทุกคำขอ
  static const Duration defaultTimeout = Duration(seconds: 20);

  /// สร้าง Header ใส่ Accept/Content-Type และแนบ Bearer token ถ้ามี
  static Future<Map<String, String>> _buildHeaders() async {
    final String? authToken = await AuthService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (authToken != null && authToken.isNotEmpty)
        'Authorization': 'Bearer $authToken',
    };
  }

  /// ประกอบ URI จาก path และ query parameters (ถ้ามี)
  static Uri _buildUri(
    String endpointPath, [
    Map<String, dynamic>? queryParameters,
  ]) {
    return Uri.parse('$baseUrl$endpointPath').replace(
      queryParameters: queryParameters == null
          ? null
          : queryParameters.map(
              (key, value) => MapEntry(key, value.toString()),
            ),
    );
  }

  /// ส่งคำขอแบบ GET
  static Future<http.Response> getRequest(
    String endpointPath, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final http.Response response = await httpClient
        .get(_buildUri(endpointPath, queryParameters),
            headers: await _buildHeaders())
        .timeout(defaultTimeout);
    _checkResponse(response);
    return response;
  }

  /// ส่งคำขอแบบ POST
  static Future<http.Response> postRequest(
    String endpointPath, {
    Object? payload,
  }) async {
    final http.Response response = await httpClient
        .post(
          _buildUri(endpointPath),
          headers: await _buildHeaders(),
          body: payload is String ? payload : jsonEncode(payload ?? {}),
        )
        .timeout(defaultTimeout);
    _checkResponse(response);
    return response;
  }

  static Future<http.Response> putRequest(String endpointPath,
      {Object? payload}) async {
    final res = await httpClient
        .put(
          _buildUri(endpointPath),
          headers: await _buildHeaders(),
          body: payload is String ? payload : jsonEncode(payload ?? {}),
        )
        .timeout(defaultTimeout);
    _checkResponse(res);
    return res;
  }

  static Future<http.Response> deleteRequest(String endpointPath,
      {Object? payload}) async {
    final res = await httpClient
        .send(http.Request('DELETE', _buildUri(endpointPath))
          ..headers.addAll(await _buildHeaders())
          ..body = payload is String ? payload : jsonEncode(payload ?? {}))
        .timeout(defaultTimeout);
    // แปลง StreamedResponse -> Response
    final r = await http.Response.fromStream(res);
    _checkResponse(r);
    return r;
  }

  /// ตรวจสอบรหัสตอบกลับทั่วไป (เพิ่ม logic refresh token ได้ในอนาคต)
  static void _checkResponse(http.Response response) {
    if (response.statusCode == 401) {
      // TODO: ถ้ามี refresh token ใส่ flow ตรงนี้ หรือเคลียร์เซสชันแล้วพากลับหน้า Login
      throw Exception('Unauthorized (401)');
    }
  }
}
