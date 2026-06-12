import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'createActivity.dart';
import 'ActivityQRgen.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class LeaderActivityPage extends StatefulWidget {
  const LeaderActivityPage({super.key});

  @override
  State<LeaderActivityPage> createState() => _LeaderActivityPageState();
}

class _LeaderActivityPageState extends State<LeaderActivityPage> {
  final Color primaryColor = const Color(0xFF6FB188);
  final Color backgroundColor = const Color(0xFFBDE2CB);
  List<dynamic> activities = [];

  @override
  void initState() {
    super.initState();
    fetchActivities();
  }

  Future<void> fetchActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final villageCode = prefs.getInt('village_code');

    if (villageCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบ village_code')),
      );
      return;
    }

    final uri = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/getActivityByVillage');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'Village_Code': villageCode}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        activities = data['data'];
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดกิจกรรมล้มเหลว: ${response.statusCode}')),
      );
    }
  }

  bool _shouldShowStartButton(dynamic activity) {
    try {
      final now = DateTime.now();

      final activityDateStr = activity['activity_date'];
      final startTime = activity['start_time'];
      final endTime = activity['end_time'];

      if (activityDateStr == null || startTime == null || endTime == null) {
        return false;
      }

      final activityDate = DateTime.parse(activityDateStr);

      // ตรวจสอบว่าวันนี้ตรงกับวันที่ของกิจกรรม
      if (now.year != activityDate.year ||
          now.month != activityDate.month ||
          now.day != activityDate.day) {
        return false;
      }
      if (activity['status'] == 3) {
        return false;
      }

      final start = DateTime.parse('$activityDateStr $startTime')
          .subtract(const Duration(minutes: 10));
      final end = DateTime.parse('$activityDateStr $endTime')
          .add(const Duration(hours: 3));

      // ✅ แสดงเฉพาะเมื่ออยู่ภายในช่วงที่กำหนด
      return now.isAfter(start) && now.isBefore(end);
    } catch (_) {
      return false;
    }
  }

  Future<void> startActivity(BuildContext context, int activityCode, int startStatus) async {
     
    final uri = Uri.parse(
      'https://student.crru.ac.th/651463011/LowCarbonAPI/api/startActivity',
    );

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'activity_code': activityCode,'startStatus':startStatus}),
      );

      final body = jsonDecode(response.body);
    } catch (e) {}
  }

  Future<void> cancelActivity(BuildContext context, int activityCode) async {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.question,
      animType: AnimType.bottomSlide,
      title: 'ยืนยันการยกเลิก',
      desc: 'คุณต้องการยกเลิกกิจกรรมนี้ใช่หรือไม่?',
      btnCancelText: 'ไม่',
      btnOkText: 'ใช่',
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        final uri = Uri.parse(
          'https://student.crru.ac.th/651463011/LowCarbonAPI/api/cancelActivity',
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
              desc: 'ยกเลิกกิจกรรมเรียบร้อยแล้ว',
              btnOkOnPress: () {
                fetchActivities(); // โหลดกิจกรรมใหม่
              },
            ).show();
          } else {
            throw Exception(body['message'] ?? 'ไม่สามารถยกเลิกกิจกรรมได้');
          }
        } catch (e) {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.error,
            animType: AnimType.bottomSlide,
            title: 'ผิดพลาด',
            desc: e.toString().replaceFirst('Exception: ', ''),
            btnOkOnPress: () {},
          ).show();
        }
      },
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('LOW CARBON COMMUNITY'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(height: screenSize.height, color: backgroundColor),
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
                const Text(
                  'กิจกรรมชุมชน',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: activities.length,
                    itemBuilder: (context, index) {
                      final activity = activities[index];
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(activity['activity_name'],
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16)),
                                        const SizedBox(height: 4),
                                        Text(
                                            'เข้าร่วม ${activity['want_count']} คน',
                                            style: const TextStyle(
                                                color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: () {
                                            final now = DateTime.now();
                                            final dateStr =
                                                activity['activity_date'];
                                            final endTimeStr =
                                                activity['end_time'];
                                            final status = activity['status'];

                                            if (dateStr != null &&
                                                endTimeStr != null &&
                                                status != 1) {
                                              try {
                                                final endDateTime =
                                                    DateTime.parse(
                                                        '$dateStr $endTimeStr');
                                                final lateThreshold =
                                                    endDateTime.add(
                                                        const Duration(
                                                            hours: 3));

                                                if (now
                                                    .isAfter(lateThreshold)) {
                                                  return Colors
                                                      .red; // กรณีหมดเวลาไปแล้วเกิน 3 ชม.
                                                }
                                              } catch (_) {}
                                            }

                                            // default ตาม status
                                            switch (status) {
                                              case 0:
                                                return Colors.grey;
                                              case 1:
                                                return Colors.green;
                                              case 2:
                                                return Colors.amber;
                                              case 3:
                                                return Colors.red;
                                              default:
                                                return Colors.grey;
                                            }
                                          }(),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          () {
                                            final now = DateTime.now();
                                            final dateStr =
                                                activity['activity_date'];
                                            final endTimeStr =
                                                activity['end_time'];
                                            final status = activity['status'];

                                            if (dateStr != null &&
                                                endTimeStr != null &&
                                                status != 1 &&
                                                status != 3) {
                                              try {
                                                final endDateTime =
                                                    DateTime.parse(
                                                        '$dateStr $endTimeStr');
                                                final lateThreshold =
                                                    endDateTime.add(
                                                        const Duration(
                                                            hours: 3));

                                                if (now
                                                    .isAfter(lateThreshold)) {
                                                  return 'หมดเวลาทำกิจกรรมแล้ว';
                                                }
                                              } catch (_) {}
                                            }

                                            // default label ตาม status
                                            switch (status) {
                                              case 0:
                                                return 'ยังไม่ถึงเวลา';
                                              case 1:
                                                return 'สิ้นสุดกิจกรรม';
                                              case 2:
                                                return 'กำลังทำกิจกรรม';
                                              case 3:
                                                return 'ยกเลิกกิจกรรม';
                                              default:
                                                return 'ไม่ทราบสถานะ';
                                            }
                                          }(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTapDown: (TapDownDetails details) {
                                          final RenderBox overlay =
                                              Overlay.of(context)
                                                      .context
                                                      .findRenderObject()
                                                  as RenderBox;
                                          showMenu(
                                            context: context,
                                            position: RelativeRect.fromLTRB(
                                              details.globalPosition.dx -
                                                  120, // เลื่อนซ้ายประมาณ 120px
                                              details.globalPosition.dy,
                                              overlay.size.width -
                                                  details.globalPosition.dx,
                                              0,
                                            ),
                                            items: [
                                              PopupMenuItem(
                                                child: InkWell(
                                                  onTap: () {
                                                    Navigator.pop(
                                                        context); // ต้องปิด popup ก่อน
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            CreateActivityPage(
                                                          activityCode: activity[
                                                              'activity_code'],
                                                          isEdit: true,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child: Center(
                                                    child: Text(
                                                      'แก้ไข',
                                                      style: TextStyle(
                                                        color:
                                                            Colors.amber[700],
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              PopupMenuItem(
                                                child: InkWell(
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    cancelActivity(
                                                        context,
                                                        activity[
                                                            'activity_code']);
                                                  },
                                                  child: Center(
                                                    child: Text(
                                                      'ยกเลิก',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            elevation: 8,
                                          );
                                        },
                                        child: const Icon(Icons.more_vert,
                                            color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(activity['detail'],
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child:
                                        Text(activity['activity_date'] ?? ''),
                                  ),
                                  if (_shouldShowStartButton(
                                      activity)) // ตรวจสอบเงื่อนไขก่อนแสดงปุ่ม
                                    ElevatedButton(
                                      onPressed: () async {
                                        await startActivity(
                                            context, activity['activity_code'],activity['status']);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                QRCodeDisplayPage(
                                              activityCode:
                                                  activity['activity_code'],
                                            ),
                                          ),
                                        ).then((_) {
                                          fetchActivities(); // โหลดใหม่เมื่อกลับ
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.grey,
                                        side: const BorderSide(
                                            color: Colors.grey),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ),
                                      child: Text(
                                          activity['status'] == 1 ||
                                                  activity['status'] == 2
                                              ? 'รายละเอียด'
                                              : 'เริ่มต้น',
                                          style: TextStyle(fontSize: 14)),
                                    ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        child: Icon(Icons.add, color: primaryColor),
        onPressed: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const CreateActivityPage()),
          );
        },
      ),
    );
  }
}
