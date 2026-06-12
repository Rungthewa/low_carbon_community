import 'package:flutter/material.dart';
import 'Register.dart';
import 'main.dart';
import 'regisHome.dart';
import 'leaderNav.dart';
import 'dart:convert';
import 'nav.dart';
import 'checkLeader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mainLeader.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'authService.dart';
import 'package:http/http.dart' as http;
import 'api.dart';
import 'forgetPass.dart';

class LoginScreen extends StatelessWidget {
  final TextEditingController telController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final Color primaryColor = const Color(0xFF6FB188); // สีเขียวพาสเทล

  void submitLogin(BuildContext context) async {
    final tel = telController.text.trim();
    final password = passwordController.text;

    if (tel.isEmpty || password.isEmpty) {
      showLoginErrorDialog(context, 'กรุณากรอกข้อมูลให้ครบ');
      return;
    }

    final body = {'tel': tel, 'password': password};

    try {
      final res = await ApiClient.postRequest('/login', payload: body);

      if (res.statusCode == 200) {
        final resBody = jsonDecode(res.body);
        final token = resBody['token'] as String?;
        final user = resBody['user'] as Map<String, dynamic>?;

        if (token != null && user != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('user_code', user['User_Code'] as int);
          await prefs.setInt('village_code', user['Village_Code'] as int);
          await prefs.setInt('home_Code', user['home_Code'] as int);
          await AuthService.saveSession(token: token, user: user);
        }

        final homeCode = int.tryParse('${user?['home_Code']}') ?? 0;

        if (user?['status'] == "3") {
          showSuspendedDialog(context);
          return;
        }

        if (user?['User_Type'] == "2") {
          if (user?['grov_code'] != null) {
            if (user?['status'] == "0") {
              showUnderReviewDialog(context);
              return;
            }
            final prefs = await SharedPreferences.getInstance();
            prefs.setBool('isLeader', true);
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => LeaderNav()));
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                  builder: (_) =>
                      CheckLeaderPage(userCode: user?['User_Code'])),
            );
          }
        } else {
          if (homeCode == 0) {
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => RegisHome()));
          } else {
            Navigator.of(context)
                .pushReplacement(MaterialPageRoute(builder: (_) => Nav()));
          }
        }
      } else {
        debugPrint('Login failed: ${res.statusCode} ${res.body}');
        showLoginErrorDialog(context, 'เบอร์หรือรหัสผ่านไม่ถูกต้อง');
      }
    } catch (e) {
      debugPrint('Connection error: $e');
      showNotConnectDialog(context);
    }
  }

  void showLoginErrorDialog(BuildContext context,
      [String message = 'เข้าสู่ระบบไม่สำเร็จ']) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.rightSlide,
      title: 'เกิดข้อผิดพลาด',
      desc: message,
      btnOkOnPress: () {},
    ).show();
  }

  void showNotConnectDialog(BuildContext context) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.leftSlide,
      title: 'ไม่สามารถเชื่อมต่อได้',
      desc: 'โปรดตรวจสอบการเชื่อมต่อเครือข่ายของคุณ',
      btnOkOnPress: () {},
    ).show();
  }

  void showSuspendedDialog(BuildContext context) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.bottomSlide,
      title: 'บัญชีถูกระงับ',
      desc: 'บัญชีของคุณถูกระงับ กรุณาติดต่อเจ้าหน้าที่เพื่อขอความช่วยเหลือ',
      btnOkOnPress: () {},
    ).show();
  }

  void showUnderReviewDialog(BuildContext context) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.info,
      animType: AnimType.scale,
      title: 'กำลังตรวจสอบ',
      desc:
          'บัญชีของคุณอยู่ระหว่างการตรวจสอบ กรุณารอจนกว่าเจ้าหน้าที่ติดต่อกลับ',
      btnOkOnPress: () {},
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double height60 = screenSize.height * 0.6;
    final double height40 = screenSize.height * 0.4;

    return Scaffold(
      body: Stack(
        children: [
          // สีเขียวพื้นหลังล่าง
          Container(color: primaryColor),

          // สีขาวส่วนบนล้นลงมา
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: screenSize.height * 0.60, // ล้นลงมาเล็กน้อย
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
            ),
          ),

          // เนื้อหาอยู่ตรงกลาง
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('images/logo.png', width: 400, height: 400),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: telController,
                          decoration: InputDecoration(
                            labelText: 'เบอร์โทร',
                            prefixIcon: Icon(Icons.phone, color: primaryColor),
                            border: OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: primaryColor),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: passwordController,
                          decoration: InputDecoration(
                            labelText: 'รหัสผ่าน',
                            prefixIcon: Icon(Icons.lock, color: primaryColor),
                            border: OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: primaryColor),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          obscureText: true,
                        ),
                        Align(
                          alignment: Alignment.centerRight, // ชิดขวา
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordPage()),
                              );
                            },
                            child: Text(
                              'ลืมรหัสผ่าน',
                              style: TextStyle(
                                color: primaryColor,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => submitLogin(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            minimumSize: Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text('เข้าสู่ระบบ',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                  builder: (context) => RegisterUserForm()),
                            );
                          },
                          child: Text(
                            'ยังไม่มีบัญชี? สมัครสมาชิก',
                            style: TextStyle(
                              color: primaryColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- DIALOGS ----------

void showNotConnectDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('ไม่สามารถเชื่อมต่อได้'),
      content: Text('โปรดตรวจสอบการเชื่อมต่อเครือข่ายของคุณ'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('ปิด'),
        ),
      ],
    ),
  );
}

void showSuccessDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('เข้าสู่ระบบสำเร็จ'),
      content: Text('ยินดีต้อนรับเข้าสู่ระบบ'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            // Navigator.pushReplacement(...);
          },
          child: Text('ดำเนินการต่อ'),
        ),
      ],
    ),
  );
}

void showLoginErrorDialog(BuildContext context,
    [String message = 'เข้าสู่ระบบไม่สำเร็จ']) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('เกิดข้อผิดพลาด'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('ตกลง'),
        ),
      ],
    ),
  );
}
