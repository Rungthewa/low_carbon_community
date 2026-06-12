import 'dart:convert';
import 'package:flutter/material.dart';
import 'api.dart'; // ใช้ ApiClient ของคุณ

class ResetPasswordPage extends StatefulWidget {
  final String phoneRaw; // เบอร์ที่ผู้ใช้กรอก (เช่น 09xxxxxxx)

  const ResetPasswordPage({super.key, required this.phoneRaw});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final Color primaryColor = const Color(0xFF6FB188);
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    final p1 = _pass.text.trim();
    final p2 = _confirm.text.trim();

    if (p1.length < 6) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('รหัสผ่านต้องอย่างน้อย 6 ตัวอักษร')));
      return;
    }
    if (p1 != p2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('รหัสผ่านไม่ตรงกัน')));
      return;
    }

    setState(() => _saving = true);
    try {
      // TODO: เปลี่ยน endpoint ให้ตรงกับหลังบ้านคุณ
      // ตัวอย่าง: POST /resetPasswordByPhone  { tel: '09xxxx', password: '...' }
      final res = await ApiClient.postRequest(
        '/resetPasswordByPhone',
        payload: {'tel': widget.phoneRaw, 'password': p1},
      );

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เปลี่ยนรหัสผ่านสำเร็จ')),
        );
        Navigator.of(context).popUntil((r) => r.isFirst); // กลับไปหน้าแรก/ล็อกอิน
      } else {
        final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
        final msg = body['message']?.toString() ?? 'เปลี่ยนรหัสผ่านไม่สำเร็จ';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เชื่อมต่อไม่สำเร็จ: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งรหัสผ่านใหม่')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'รหัสผ่านใหม่'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'ยืนยันรหัสผ่านใหม่'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('บันทึก', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
