import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'Joiner.dart';


class JoinActivityPage extends StatefulWidget {
  final int activityCode;

  const JoinActivityPage({super.key, required this.activityCode});

  @override
  State<JoinActivityPage> createState() => _JoinActivityPageState();
}

class _JoinActivityPageState extends State<JoinActivityPage> {
  final Color primaryColor = const Color(0xFF6FB188);
  Map<String, dynamic>? activity;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchActivityDetail();
  }

  Future<void> fetchActivityDetail() async {
    final url =
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/joinDetail/${widget.activityCode}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          activity = body['data'];
          isLoading = false;
        });
      } else {
        print('Error: ${response.body}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Exception: $e');
      setState(() => isLoading = false);
    }
  }

  String buildTreeSummary(List<dynamic> treeDetail) {
    final buffer = StringBuffer();

    for (var tree in treeDetail) {
      final name = tree['tree_Name'] ?? 'ไม่ทราบชื่อ';
      final count = tree['count'] ?? 0;
      buffer.writeln('$name จำนวน $count ต้น');
    }

    return buffer.toString().trim();
  }

  Future<void> joinActvity() async {
    final prefs = await SharedPreferences.getInstance();
    final userCode = prefs.getInt('user_code') ?? 0;

    final response = await http.post(
      Uri.parse('https://student.crru.ac.th/651463011/LowCarbonAPI/api/joinActivity'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_code': userCode,
        'activity_code': widget.activityCode,
      }),
    );

    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      if (result['status'] == 200) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.scale,
          title: 'สำเร็จ',
          desc: 'บันทึกกิจกรรมเรียบร้อยแล้ว',
          btnOkOnPress: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => JoinActivityListPage(),
              ),
            );
          },
        ).show();
      }
    } else if (response.statusCode == 409) {
      // เคย join แล้ว
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("แจ้งเตือน"),
          content: const Text("คุณได้เข้าร่วมกิจกรรมนี้แล้ว"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("ตกลง"),
            ),
          ],
        ),
      );
    } else {
      print('Error joining: ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการเข้าร่วมกิจกรรม')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text("รายละเอียดกิจกรรม"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : activity == null
              ? const Center(child: Text("ไม่พบข้อมูลกิจกรรม"))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 6),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity!['activity_name'] ?? 'ไม่ระบุชื่อกิจกรรม',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildLabel("รายละเอียด", activity!['detail']),
                          const SizedBox(height: 12),
                          _buildLabel(
                            "ต้นไม้ที่จะปลูก",
                            buildTreeSummary(activity!['tree_details'] ?? []),
                          ),
                          const SizedBox(height: 12),
                          _buildLabel(
                            "เวลาเริ่มต้นและสิ้นสุดกิจกรรม",
                            "${activity!['start_time'] ?? '-'} - ${activity!['end_time'] ?? '-'}",
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: Text(
                              "วันที่ ${activity!['activity_date'] ?? '-'}",
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: ElevatedButton(
                              onPressed: () {
                                joinActvity();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Text("เข้าร่วมกิจกรรม"),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Center(
                            child: IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.red, size: 36),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildLabel(String title, String? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: primaryColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value ?? '-',
          style: TextStyle(color: primaryColor, fontSize: 14),
        ),
      ],
    );
  }
}
