import 'package:flutter/material.dart';
import 'LoginScreen.dart';
import 'leaderNav.dart';
import 'nav.dart';
import 'regisHome.dart';
import 'checkLeader.dart';
import 'authService.dart'; // <- ใช้ AuthService ที่เราเซ็ตไว้

class SplashScreen extends StatefulWidget {
  
  const SplashScreen({super.key});
  
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final Color primaryColor = const Color(0xFF6FB188);

  @override
  void initState() {
    super.initState();
    _decideRoute();
  }

  Future<void> _decideRoute() async {
    try {
      final has = await AuthService.hasSession(); // มี token เก็บไว้ไหม
      if (!mounted) return;

      if (!has) {
        _go(LoginScreen());
        return;
      }

      final user = await AuthService.getUser(); // Map<String,dynamic>?
      if (user == null) {
        await AuthService.clearSession();
        _go(LoginScreen());
        return;
      }

      final status   = '${user['status']}';
      final userType = '${user['User_Type']}';
      final homeCode = int.tryParse('${user['home_Code']}') ?? 0;
      final grovCode = user['grov_code'];

      // ถูกระงับ
      if (status == '3') {
        await AuthService.clearSession();
        _go(LoginScreen());
        return;
      }

      if (userType == '2') {
        // ผู้นำชุมชน
        if (grovCode != null) {
          if (status == '0') {
            // ระหว่างตรวจสอบ
            _go(LoginScreen());
          } else {
            _go(LeaderNav());
          }
        } else {
          _go(CheckLeaderPage(userCode: int.tryParse('${user['User_Code']}') ?? 0));
        }
      } else {
        // ผู้ใช้ทั่วไป
        if (homeCode == 0) {
          _go(RegisHome());
        } else {
          _go(Nav());
        }
      }
    } catch (_) {
      if (!mounted) return;
      _go(LoginScreen());
    }
  }

  void _go(Widget page) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5FDF9),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset('images/logo.png'),
            const SizedBox(height: 20.0),
            const CircularProgressIndicator(
              color: Color(0xFF6FB188), // สีเขียวพาสเทล
            ),
            const SizedBox(height: 10.0),
            const Text(
              'กำลังโหลด...',
              style: TextStyle(fontSize: 16.0, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
