import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'AccoutSetting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class SentReportPage extends StatefulWidget {
  @override
  _SentReportPageState createState() => _SentReportPageState();
}

class _SentReportPageState extends State<SentReportPage> {
  final Color primaryColor = Color(0xFF6FB188);
  String? selectedTopic;
  TextEditingController detailController = TextEditingController();
  int? selectedTopicValue;

  List<Map<String, dynamic>> topics = [
    {'label': 'แอปใช้งานไม่ได้', 'value': 1},
    {'label': 'ไม่สามารถบันทึกข้อมูล', 'value': 2},
    {'label': 'ข้อมูลไม่ถูกต้อง', 'value': 3},
    {'label': 'อื่น ๆ', 'value': 4},
  ];

  void submitReport() async {
    if (selectedTopicValue == null || detailController.text.isEmpty) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        title: 'กรุณากรอกข้อมูลให้ครบถ้วน',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userCode = prefs.getInt('user_code');

    if (userCode == null) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        title: 'ไม่พบรหัสผู้ใช้งาน',
        desc: 'กรุณาเข้าสู่ระบบอีกครั้ง',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    final url =
        Uri.parse('https://student.crru.ac.th/651463011/LowCarbonAPI/api/sentReport');
    final body = {
      'user_code': userCode.toString(),
      'topic': selectedTopicValue.toString(),
      'detail': detailController.text,
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode == 200) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          title: 'ส่งรายงานสำเร็จ',
          desc: 'ขอบคุณสำหรับการแจ้งปัญหา',
          btnOkOnPress: () {
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => AccountSettingPage()),
              );
          },
        ).show();
      } else {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'ผิดพลาด',
          desc: 'ไม่สามารถส่งรายงานได้ (${response.statusCode})',
          btnOkOnPress: () {},
        ).show();
      }
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        title: 'ข้อผิดพลาดเครือข่าย',
        desc: e.toString(),
        btnOkOnPress: () {},
      ).show();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: primaryColor,
        leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => AccountSettingPage()),
              );
            }),
        title: Text('ติดต่อเจ้าหน้าที่'),
      ),
      body: Stack(
        children: [
          Container(height: screenSize.height, color: Color(0xFFBDE2CB)),
          Positioned(
            top: screenSize.height * 0.08,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // ไอคอนตรงกลาง
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 40,
                      child: Icon(Icons.support_agent,
                          size: 40, color: primaryColor),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'รายงานปัญญาที่คุณพบเจอให้เจ้าหน้าที่เพื่อแจ้งให้เจ้าหน้าที่ทราบหรือติดต่อ 099-999-9999',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // หัวเรื่อง
                    DropdownButtonFormField<int>(
                      value: selectedTopicValue,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFD1E7D0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                      hint: Text('หัวเรื่อง'),
                      items: topics.map((topic) {
                        return DropdownMenuItem<int>(
                          value: topic['value'],
                          child: Text(topic['label']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedTopicValue = value;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // รายละเอียด
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('รายละเอียด'),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: Color(0xFFD1E7D0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: detailController,
                        maxLines: 6,
                        decoration: InputDecoration(
                          hintText: '',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ปุ่มส่งรายงาน
                    ElevatedButton(
                      onPressed: submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding:
                            EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: StadiumBorder(),
                      ),
                      child: Text('ส่งรายงาน'),
                    )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
