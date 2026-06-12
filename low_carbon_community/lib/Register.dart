import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'LoginScreen.dart';
import 'checkLeader.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'OTPverifyRegis.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api.dart';

class RegisterUserForm extends StatefulWidget {
  @override
  _RegisterUserFormState createState() => _RegisterUserFormState();
}

class _RegisterUserFormState extends State<RegisterUserForm> {
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  int selectedUserType = 1;
  List<dynamic> villageList = [];
  String? selectedVillageCode;

  int? _resendToken;
  bool _sendingOtp = false;

  @override
  void initState() {
    super.initState();
    fetchVillageList();
  }

  Future<void> fetchVillageList() async {
    try {
      final res = await ApiClient.getRequest('/villageList');
      if (res.statusCode == 200) {
        setState(() {
          villageList = jsonDecode(res.body) as List<dynamic>;
        });
      } else {
        debugPrint(
            'Failed to load village list: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('Failed to load village list: $e');
    }
  }

  void registerUser() async {
    final requestBody = {
      'User_Name': '${firstNameController.text} ${lastNameController.text}',
      'email': emailController.text,
      'tel': phoneController.text,
      'password': passwordController.text,
      'User_Type': selectedUserType.toString(),
      'Village_Code': selectedVillageCode ?? '',
    };

    try {
      final res =
          await ApiClient.postRequest('/Register', payload: requestBody);

      if (res.statusCode == 201) {
        if (selectedUserType == 2) {
          final userCode =
              int.tryParse((requestBody['User_Code'] ?? '0').toString()) ?? 0;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
                builder: (_) => CheckLeaderPage(userCode: userCode)),
          );
        } else {
          showSuccessDialog(context);
        }
      } else {
        debugPrint('Register error: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('Register exception: $e');
    }
  }

  Future<void> sendOTP(String phoneNumber) async {
    setState(() => _sendingOtp = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // อาจ auto-verify บางเครื่อง/บางเครือข่าย
          // ไม่ต้อง register ที่นี่ เพื่อให้ flow เดียวกันผ่านหน้า OTP
          // แต่ถ้าต้องการ auto ต่อเลย ก็สามารถ signIn แล้วเรียก registerUser() ได้
        },
        verificationFailed: (FirebaseAuthException e) {
          final msg = _mapPhoneAuthError(e);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        },
        codeSent: (String verificationId, int? resendToken) {
          _resendToken = resendToken;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerificationPage(
                verificationId: verificationId,
                onVerified: () => registerUser(), // ✅ สมัครหลังยืนยันสำเร็จ
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // ไม่ได้ error แค่หมดเวลา auto-retrieve
        },
        timeout: const Duration(seconds: 60),
      );
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  String _mapPhoneAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'รูปแบบเบอร์ไม่ถูกต้อง (ต้องเป็น E.164 เช่น +669xxxxxxxx)';
      case 'quota-exceeded':
        return 'โควต้า SMS ของโปรเจ็กต์เต็ม กรุณาลองใหม่ภายหลัง';
      case 'captcha-check-failed':
        return 'การตรวจสอบความปลอดภัยล้มเหลว ลองใหม่';
      case 'too-many-requests':
        return 'ลองหลายครั้งเกินไป รอสักครู่แล้วลองใหม่';
      default:
        return e.message ?? 'เกิดข้อผิดพลาดในการส่ง OTP';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Color(0xFF6FB188);

    return Scaffold(
      appBar: AppBar(
        title: Text('หน้าลงทะเบียน'),
        backgroundColor: primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 20),
            buildTextField(
                firstNameController, 'ชื่อ', Icons.person, primaryColor),
            buildTextField(lastNameController, 'นามสกุล', Icons.person_outline,
                primaryColor),
            buildTextField(emailController, 'อีเมล', Icons.email, primaryColor,
                TextInputType.emailAddress),
            buildTextField(phoneController, 'เบอร์โทร', Icons.phone,
                primaryColor, TextInputType.phone),
            buildTextField(passwordController, 'รหัสผ่าน', Icons.lock,
                primaryColor, TextInputType.text, true),
            SizedBox(height: 20),
            Text('ประเภทผู้ใช้:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<int>(
                    activeColor: primaryColor,
                    title: Text('ผู้ใช้งานธรรมดา'),
                    value: 1,
                    groupValue: selectedUserType,
                    onChanged: (val) => setState(() => selectedUserType = val!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<int>(
                    activeColor: primaryColor,
                    title: Text('ผู้นำชุมชน'),
                    value: 2,
                    groupValue: selectedUserType,
                    onChanged: (val) => setState(() => selectedUserType = val!),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            DropdownButtonHideUnderline(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 500),
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedVillageCode,
                    items: villageList.map((village) {
                      final String name =
                          village['Village_Name'] ?? 'ไม่ทราบชื่อ';
                      return DropdownMenuItem<String>(
                        value: village['Village_Code'].toString(),
                        child: Tooltip(
                          message: name,
                          waitDuration: Duration(milliseconds: 500),
                          child: Container(
                            width: double.infinity,
                            child: Row(
                              children: [
                                Icon(Icons.home_outlined,
                                    color: Colors.green, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    name,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedVillageCode = value;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'หมู่บ้าน',
                      labelStyle: TextStyle(color: Colors.green),
                      prefixIcon: Icon(Icons.location_on, color: Colors.green),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.green),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                String rawPhone = phoneController.text.trim();
                if (rawPhone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('กรุณากรอกเบอร์โทร')),
                  );
                  return;
                }
                // แปลง E.164 (ไทย)
                final e164 = rawPhone.startsWith('+')
                    ? rawPhone
                    : (rawPhone.startsWith('0')
                        ? '+66${rawPhone.substring(1)}'
                        : '+66$rawPhone');

                sendOTP(e164); // ✅ ส่ง OTP อย่างเดียว
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
              ),
              child: Text(
                'ลงทะเบียน',
                style: TextStyle(color: Colors.white),
              ),
            ),
            SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(),
                  ),
                );
              },
              child: Text(
                'กลับไปยังหน้า Login',
                style: TextStyle(color: primaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTextField(
    TextEditingController controller,
    String labelText,
    IconData icon,
    Color primaryColor, [
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  ]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: primaryColor),
          labelText: labelText,
          labelStyle: TextStyle(color: primaryColor),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: primaryColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
          ),
        ),
        keyboardType: keyboardType,
        obscureText: obscureText,
      ),
    );
  }
}

void showSuccessDialog(BuildContext context) {
  AwesomeDialog(
    context: context,
    dialogType: DialogType.success,
    animType: AnimType.rightSlide,
    title: 'ลงทะเบียนสำเร็จ',
    desc: 'ข้อมูลของคุณถูกบันทึกแล้ว',
    btnOkText: 'เข้าสู่ระบบ',
    btnOkOnPress: () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => LoginScreen(),
        ),
      );
    },
  ).show();
}
