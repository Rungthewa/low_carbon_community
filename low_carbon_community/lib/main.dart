import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // ✅ เพิ่มบรรทัดนี้
import 'splash_screen.dart';
import 'firebase_options.dart'; // ✅ นำเข้า options ที่เพิ่งสร้าง
import 'LoginScreen.dart';
import 'dailyReduce.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await scheduleDailyLog();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: 'Kanit',
      ),
      debugShowCheckedModeBanner: false,
      home: SplashScreen(), // ✅ หน้าหลักเริ่มที่ SplashScreen
    );
  }
}
