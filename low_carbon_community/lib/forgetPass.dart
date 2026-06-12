import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'OTPverifyForget.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final Color primaryColor = const Color(0xFF6FB188);
  final TextEditingController phoneController = TextEditingController();
  bool sending = false;

  String _toE164(String raw) {
    String p = raw.trim();
    if (p.startsWith('0')) return '+66${p.substring(1)}';
    if (!p.startsWith('+')) return '+$p';
    return p;
  }

  Future<void> _sendOtp() async {
    final raw = phoneController.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกเบอร์โทร')),
      );
      return;
    }

    final phoneE164 = _toE164(raw);
    setState(() => sending = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneE164,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (cred) async {
          // บางกรณี Android auto-verify ได้เลย
          await FirebaseAuth.instance.signInWithCredential(cred);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerifyResetPage(
                verificationId: 'auto', // ไม่ได้ใช้ในกรณี auto
                rawPhone: raw,
                phoneE164: phoneE164,
                autoVerified: true,
              ),
            ),
          );
        },
        verificationFailed: (e) {
          String msg = e.message ?? 'ส่ง OTP ไม่สำเร็จ';
          if (e.code == 'invalid-phone-number') {
            msg = 'รูปแบบเบอร์ไม่ถูกต้อง (ต้องเป็น E.164)';
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerifyResetPage(
                verificationId: verificationId,
                rawPhone: raw,
                phoneE164: phoneE164,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ลืมรหัสผ่าน')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('กรอกเบอร์โทรเพื่อรับรหัส OTP สำหรับรีเซ็ตรหัสผ่าน'),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'เบอร์โทร (เช่น 09xxxxxxxx)',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: sending ? null : _sendOtp,
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: sending
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('ส่งรหัส OTP', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
