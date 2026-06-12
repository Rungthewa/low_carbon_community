import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class OtpVerificationPage extends StatefulWidget {
  final String verificationId;
  final VoidCallback onVerified;

  const OtpVerificationPage({
    Key? key,
    required this.verificationId,
    required this.onVerified,
  }) : super(key: key);

  @override
  _OtpVerificationPageState createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final Color primaryColor = const Color(0xFF6FB188);

  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _verifying = false;

  @override
  void dispose() {
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String _collectCode() => _otpCtrls.map((c) => c.text).join();

  void _handleChanged(int index, String value) {
    // รองรับการ paste หลายหลักทีเดียว
    if (value.length > 1) {
      _spreadPastedValue(value);
      return;
    }

    if (value.isNotEmpty) {
      // ไปช่องถัดไป
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        FocusScope.of(context).unfocus();
      }
    } else {
      // ถ้าลบแล้วว่าง ให้ย้อนกลับช่องก่อนหน้า
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
        _otpCtrls[index - 1].selection = TextSelection(
          baseOffset: 0,
          extentOffset: _otpCtrls[index - 1].text.length,
        );
      }
    }
    setState(() {}); // ให้ปุ่มยืนยัน enable/disable ตามความครบ
  }

  void _spreadPastedValue(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    for (int i = 0; i < 6; i++) {
      _otpCtrls[i].text = (i < digits.length) ? digits[i] : '';
    }
    if (digits.length >= 6) {
      FocusScope.of(context).unfocus();
    } else {
      _focusNodes[digits.length].requestFocus();
    }
    setState(() {});
  }

  Future<void> verifyCode() async {
    final smsCode = _collectCode();
    if (smsCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอก OTP ให้ครบ 6 หลัก')),
      );
      return;
    }

    setState(() => _verifying = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: smsCode,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      // (ทางเลือก) ส่ง Firebase ID token ให้ backend ตรวจสอบความถูกต้องเพิ่มเติม
      // final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();

      widget.onVerified();
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'invalid-verification-code':
          msg = 'OTP ไม่ถูกต้อง';
          break;
        case 'session-expired':
          msg = 'รหัสหมดอายุ กรุณาขอรหัสใหม่';
          break;
        case 'invalid-verification-id':
          msg = 'เซสชัน OTP ไม่ถูกต้อง กลับไปส่งรหัสใหม่อีกครั้ง';
          break;
        default:
          msg = e.message ?? 'ยืนยัน OTP ไม่สำเร็จ';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  InputDecoration _boxDecoration() => InputDecoration(
        counterText: '',
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      );

  Widget _otpBox(int index) {
    return SizedBox(
      width: 48,
      child: TextField(
        controller: _otpCtrls[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        decoration: _boxDecoration(),
        onChanged: (val) => _handleChanged(index, val),
        onTap: () {
          // select-all เพื่อพิมพ์ทับได้ทันที
          _otpCtrls[index].selection = TextSelection(
            baseOffset: 0,
            extentOffset: _otpCtrls[index].text.length,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isComplete = _collectCode().length == 6;

    return Scaffold(
      appBar: AppBar(
        title: const Text("ยืนยัน OTP"),
        backgroundColor: primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text("กรุณากรอก OTP ที่ส่งไปยังเบอร์โทรของคุณ"),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, _otpBox),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (_verifying || !isComplete) ? null : verifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  disabledBackgroundColor: primaryColor.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _verifying
                    ? const CircularProgressIndicator()
                    : const Text(
                        "ยืนยัน",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
