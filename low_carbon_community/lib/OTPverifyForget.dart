import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'resetPass.dart';

class OtpVerifyResetPage extends StatefulWidget {
  final String verificationId;
  final String rawPhone;   // เบอร์รูปแบบที่ผู้ใช้กรอก (เช่น 09xxxxxxx)
  final String phoneE164;  // เบอร์รูปแบบ E.164 (เช่น +669xxxxxxx)
  final bool autoVerified;

  const OtpVerifyResetPage({
    super.key,
    required this.verificationId,
    required this.rawPhone,
    required this.phoneE164,
    this.autoVerified = false,
  });

  @override
  State<OtpVerifyResetPage> createState() => _OtpVerifyResetPageState();
}

class _OtpVerifyResetPageState extends State<OtpVerifyResetPage> {
  final Color primaryColor = const Color(0xFF6FB188);
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _nodes = List.generate(6, (_) => FocusNode());
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoVerified) {
      // ข้าม OTP กรณี auto-verified สำเร็จ
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ResetPasswordPage(phoneRaw: widget.rawPhone)),
        );
      });
    }
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอก OTP ให้ครบ 6 หลัก')),
      );
      return;
    }
    setState(() => _verifying = true);
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _code,
      );
      await FirebaseAuth.instance.signInWithCredential(cred);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ResetPasswordPage(phoneRaw: widget.rawPhone)),
      );
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'invalid-verification-code':
          msg = 'OTP ไม่ถูกต้อง';
          break;
        case 'session-expired':
          msg = 'รหัสหมดอายุ กรุณาขอใหม่';
          break;
        case 'invalid-verification-id':
          msg = 'เซสชันไม่ถูกต้อง กรุณาส่งรหัสใหม่';
          break;
        default:
          msg = e.message ?? 'ยืนยัน OTP ไม่สำเร็จ';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Widget _otpBox(int i) {
    return SizedBox(
      width: 48,
      child: TextField(
        controller: _controllers[i],
        focusNode: _nodes[i],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
        ),
        onChanged: (v) {
          if (v.isNotEmpty && i < 5) {
            _nodes[i + 1].requestFocus();
          } else if (v.isEmpty && i > 0) {
            _nodes[i - 1].requestFocus();
          }
        },
        onSubmitted: (v) {
          if (i == 5) _verify();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boxes = List<Widget>.generate(6, (i) => _otpBox(i));

    return Scaffold(
      appBar: AppBar(title: const Text('ยืนยันรหัส OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('ป้อนรหัส 6 หลักที่ส่งไปยัง ${widget.phoneE164}'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: boxes,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _verifying ? null : _verify,
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: _verifying
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
