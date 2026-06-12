import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const auth_Token = 'auth_token';
  static const auth_User = 'user_json';

  /// เรียกตอนล็อกอินสำเร็จ
  static Future<void> saveSession({
    required String token,
    required Map<String, dynamic> user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(auth_Token, token);
    await prefs.setString(auth_User, jsonEncode(user));
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(auth_Token);
    await prefs.remove(auth_User);
    // ถ้ามี key อื่นๆ ที่คุณเก็บไว้ เช่น user_code, village_code ก็ลบด้วย
    await prefs.remove('user_code');
    await prefs.remove('village_code');
    await prefs.remove('home_Code');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(auth_Token);
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(auth_User);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// ใช้แนบ header กับทุก request
  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  /// ใช้ตัดสินใจ auto-login: แค่มี token + user ก็พาเข้าได้
  /// (ถ้าต้อง “ตรวจสอบจริง” แนะนำเรียก /me หรือ /validate token ที่เซิร์ฟเวอร์ด้วย)
  static Future<bool> hasSession() async {
    final t = await getToken();
    final u = await getUser();
    return t != null && t.isNotEmpty && u != null;
  }
}