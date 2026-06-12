import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'LoginScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class CheckLeaderPage extends StatefulWidget {
  final int userCode;

  const CheckLeaderPage({Key? key, required this.userCode}) : super(key: key);

  @override
  State<CheckLeaderPage> createState() => _CheckLeaderPageState();
}

class _CheckLeaderPageState extends State<CheckLeaderPage> {
  final Color primaryColor = const Color(0xFF6FB188);
  final TextEditingController idController = TextEditingController();
  File? selectedImage;

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        selectedImage = File(picked.path);
      });
    }
  }

  Future<void> submit() async {
    if (idController.text.isEmpty) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        title: 'แจ้งเตือน',
        desc: 'กรุณากรอกเลขบัตรเจ้าหน้าที่รัฐ',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    final url =
        Uri.parse('https://student.crru.ac.th/651463011/LowCarbonAPI/api/checkLeader');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    try {
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Accept'] = 'application/json';

      request.fields['grov_code'] = idController.text.trim();
      request.fields['User_Code'] = widget.userCode.toString();

      if (selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('img', selectedImage!.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          title: 'ส่งข้อมูลสำเร็จ',
          desc: 'เราได้รับข้อมูลของท่านแล้ว กรุณารอเจ้าหน้าที่ตรวจสอบ',
          btnOkOnPress: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => LoginScreen()),
            );
          },
        ).show();
      } else {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'ผิดพลาด',
          desc: 'เกิดข้อผิดพลาด: ${response.statusCode}',
          btnOkOnPress: () {},
        ).show();
      }
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        title: 'เชื่อมต่อไม่ได้',
        desc: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์: $e',
        btnOkOnPress: () {},
      ).show();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryColor.withOpacity(0.8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => LoginScreen(),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 8),
              const Text(
                'ระบุเลขบัตรประจำตัวเจ้าหน้าที่รัฐ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.black26,
                child: Icon(Icons.person, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: idController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'เลขบัตรประจำตัวเจ้าหน้าที่รัฐ',
                  filled: true,
                  fillColor: Colors.green.shade200,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (selectedImage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      selectedImage!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ElevatedButton(
                onPressed: pickImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: primaryColor,
                  shape: const StadiumBorder(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('เลือกรูปภาพแนบเพิ่มเติม'),
              ),
              const SizedBox(height: 24),
              const Text(
                'เมื่อกรอกข้อมูลเสร็จสิ้น กรุณารอเจ้าหน้าที่ติดต่อกลับ\nจึงสามารถเข้าสู่ระบบได้',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade800,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                  ),
                  child: const Text(
                    'ส่งข้อมูล',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
