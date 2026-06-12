import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:barcode_widget/barcode_widget.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'leaderActivity.dart';

class QRCodeDisplayPage extends StatefulWidget {
  final int activityCode;

  const QRCodeDisplayPage({super.key, required this.activityCode});

  @override
  State<QRCodeDisplayPage> createState() => _QRCodeDisplayPageState();
}

class _QRCodeDisplayPageState extends State<QRCodeDisplayPage> {
  final Color primaryColor = const Color(0xFF6FB188);
  final Color backgroundColor = const Color(0xFFBDE2CB);

  late Future<Map<String, dynamic>> activityFuture;

  @override
  void initState() {
    super.initState();
    activityFuture = fetchActivityDetail();
  }

  Future<Map<String, dynamic>> fetchActivityDetail() async {
    final url =
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/joinDetail/${widget.activityCode}';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      print(body);
      return body['data'];
    } else {
      throw Exception("ไม่สามารถโหลดข้อมูลกิจกรรมได้");
    }
  }

  Future<void> endActivity(BuildContext context, int activityCode) async {
    final uri = Uri.parse(
      'https://student.crru.ac.th/651463011/LowCarbonAPI/api/UpdateActivityStatus',
    );

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'activity_code': activityCode}),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['status'] == true) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.bottomSlide,
          title: 'สำเร็จ',
          desc: 'สิ้นสุดกิจกรรมเรียบร้อยแล้ว',
          btnOkOnPress: () {},
        ).show();
      } else {
        throw Exception(body['message'] ?? 'ไม่สามารถอัปเดตกิจกรรมได้');
      }
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.bottomSlide,
        title: 'เกิดข้อผิดพลาด',
        desc: '$e',
        btnOkOnPress: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => LeaderActivityPage()),
          );
        },
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
        title: const Text('LOW CARBON COMMUNITY'),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: activityFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("เกิดข้อผิดพลาด: ${snapshot.error}"));
          }

          final activity = snapshot.data!;
          final treeSummary = (activity['tree_details'] as List)
              .map((e) =>
                  "${e['tree_Name'] ?? 'ไม่ทราบชื่อ'} จำนวน ${e['count']} ต้น")
              .join("\n");

          return Stack(
            children: [
              Container(
                height: screenSize.height,
                color: backgroundColor,
              ),
              Positioned(
                top: screenSize.height * 0.08,
                left: 0,
                right: 0,
                child: Container(
                  height: screenSize.height * 0.92,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      "กิจกรรม${activity['activity_type']}",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Text(
                                activity['activity_name'],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text("รายละเอียด",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(activity['detail'] ?? '-'),
                            const SizedBox(height: 16),
                            const Text("ชนิดต้นไม้ที่ปลูก",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(treeSummary),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("จำนวนคนเข้าร่วม",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                    Text(
                                        '${activity['joined_count']}/${activity['want_count']}' ??
                                            '-'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 60),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("ระยะเวลากิจกรรม",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                    Text(
                                        "${activity['start_time']?.substring(0, 5)} - ${activity['end_time']?.substring(0, 5)}"),
                                  ],
                                ),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            const Center(child: Text("สแกนเลย")),
                            const SizedBox(height: 8),
                            Center(
                              child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: BarcodeWidget(
                                    data: activity['activity_code'].toString(),
                                    barcode: Barcode
                                        .qrCode(), // ✅ เปลี่ยนจาก Barcode.code128() เป็น qrCode
                                    width: 200,
                                    height: 200,
                                  )),
                            ),
                            const SizedBox(height: 16),
                            Center(
                                child: Text(
                                    "วันที่ ${activity['activity_date']}")),
                            const SizedBox(height: 16),
                            Center(
                              child: GestureDetector(
                                onTap: () => endActivity(
                                    context, activity['activity_code']),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Text(
                                    "สิ้นสุดกิจกรรม",
                                    style: TextStyle(color: Colors.green),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(
                              height: 16,
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
