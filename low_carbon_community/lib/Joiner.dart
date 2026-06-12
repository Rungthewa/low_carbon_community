import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ScanCam.dart';

class JoinActivityListPage extends StatefulWidget {
  const JoinActivityListPage({super.key});

  @override
  State<JoinActivityListPage> createState() => _JoinActivityListPageState();
}

class _JoinActivityListPageState extends State<JoinActivityListPage> {
  final Color primaryColor = const Color(0xFF6FB188);
  List<dynamic> joinedActivities = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchJoinedActivities();
  }

  Future<void> fetchJoinedActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final userCode = prefs.getInt('user_code') ?? 0;

    final url = 'https://student.crru.ac.th/651463011/LowCarbonAPI/api/getJoinActivity';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_code': userCode}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          joinedActivities = body['data'];
          isLoading = false;
        });
      } else {
        print("Error: ${response.body}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Exception: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        title: const Text("กิจกรรมที่เข้าร่วม"),
        backgroundColor: primaryColor,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : joinedActivities.isEmpty
              ? const Center(child: Text("ยังไม่มีกิจกรรมที่เข้าร่วม"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: joinedActivities.length,
                  itemBuilder: (context, index) {
                    final activity = joinedActivities[index];
                    final statusInfo = getActivityStatusInfo(activity);
                    final statusText = statusInfo['text'];
                    final statusColor = statusInfo['color'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 6),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // หัวเรื่อง + จำนวนเข้าร่วม
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                activity['activity_name'] ?? '-',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "เข้าร่วม ${activity['joined_count'] ?? '-'} / ${activity['want_count'] ?? '-'}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // รายละเอียด
                          Text(
                            activity['detail'] ?? '-',
                            style: TextStyle(color: primaryColor, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    "${activity['activity_date'] ?? '-'} ${activity['start_time']?.toString().substring(0, 5) ?? ''}",
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: statusColor),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QRScannerPage()),
          );

          if (result != null) {
            print("QR Code ที่ได้: $result");

            // TODO: คุณสามารถใช้ result นี้:
            // - ดึงข้อมูลกิจกรรมจาก API
            // - เช็คว่าร่วมกิจกรรมนี้หรือยัง
            // - ไปยังหน้าเข้าร่วมกิจกรรมเลย
          }
        },
        child: Icon(Icons.qr_code_scanner,
            color: primaryColor), // หรือ Icons.add ก็ได้
      ),
    );
  }

  Map<String, dynamic> getActivityStatusInfo(Map<String, dynamic> activity) {
    final now = DateTime.now();

    try {
      final aproveStatus = activity['aprove_status'] ?? 0;

      if (aproveStatus == 1) {
        return {
          'text': "สำเร็จกิจกรรม",
          'color': primaryColor,
        };
      }

      final start = DateTime.parse(
          "${activity['activity_date']} ${activity['start_time']}");
      final end = DateTime.parse(
          "${activity['activity_date']} ${activity['end_time']}");

      if (now.isBefore(start)) {
        return {
          'text': "ยังไม่เริ่ม",
          'color': Colors.blue,
        };
      }

      if (now.isAfter(end)) {
        return {
          'text': "สิ้นสุดแล้ว",
          'color': Colors.red,
        };
      }

      return {
        'text': "กิจกรรมกำลังเริ่ม",
        'color': Colors.orange,
      };
    } catch (_) {
      return {
        'text': "-",
        'color': Colors.black54,
      };
    }
  }
}
