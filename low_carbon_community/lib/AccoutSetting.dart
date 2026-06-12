import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'LoginScreen.dart';
import 'updateAccount.dart';
import 'homeSetting.dart';
import 'sentReport.dart';
import 'authService.dart';
import 'regisHome.dart';
import 'nav.dart';
import 'leaderNav.dart';

class AccountSettingPage extends StatefulWidget {
  @override
  _AccountSettingPageState createState() => _AccountSettingPageState();
}

class _AccountSettingPageState extends State<AccountSettingPage> {
  final Color primaryColor = Color(0xFF6FB188);

  String userName = '-';
  String villageName = '-';
  String homeNumber = '-';
  String role = '-';
  String? userImage;
  bool isLoading = true;
  String userType = '-';
  bool isLeader = false; // ✅ ใช้งานจริง
  int homeCode = 0;

  ImageProvider<Object> getProfileImage() {
    if (userImage != null && userImage!.trim().isNotEmpty) {
      return NetworkImage(userImage!);
    } else {
      return AssetImage('images/default.png'); // ใส่ภาพโปรไฟล์เริ่มต้น
    }
  }

  @override
  void initState() {
    super.initState();
    fetchAccountData();
    setLeader();
  }

  Future<void> setLeader() async {
    final prefs = await SharedPreferences.getInstance();

    // ✅ default ต้องเป็น bool ไม่ใช่ string
    final bool leader = prefs.getBool('isLeader') ?? false;
    final int hCode = prefs.getInt('home_Code') ?? 0;

    if (!mounted) return;
    setState(() {
      isLeader = leader;
      homeCode = hCode;
    });
  }

  Future<void> changeLeader() async {
    final prefs = await SharedPreferences.getInstance();
    if(isLeader){
      prefs.setBool('isLeader', false);
    }
    else{
      prefs.setBool('isLeader', true);
    }
    
  }

  Future<void> fetchAccountData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final userCode = prefs.getInt('user_code') ?? 0;

    final url = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/getAccount/$userCode');

    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          userName = data['User_Name'] ?? '-';
          villageName = data['Village_Name'] ?? '-';
          homeNumber = data['Home_number'] ?? '-';
          userImage = data['user_img'];
          userType = data['User_Type'] ?? '';
          role = (userType == '1') ? 'สมาชิกครัวเรือน' : 'ผู้นำชุมชนครัวเรือน';
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Fetch account error: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text('LOW CARBON COMMUNITY'),
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
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: primaryColor))
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundImage: getProfileImage(),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(userName,
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  Text(villageName,
                                      style: TextStyle(
                                          fontSize: 16, color: Colors.green)),
                                  const SizedBox(height: 4),
                                  Text(role,
                                      style: TextStyle(
                                          fontSize: 14, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          ListTile(
                            leading:
                                Icon(Icons.person_outline, color: primaryColor),
                            title: const Text('โปรไฟล์ของฉัน'),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (_) => UpdateAccountPage()),
                                (route) => false,
                              );
                            },
                          ),
                          // … ด้านใน build
                          if (userType == '1') ...[
                            const Divider(),
                            ListTile(
                              leading: Icon(Icons.home_outlined,
                                  color: primaryColor),
                              title: const Text('ครัวเรือน'),
                              trailing:
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => HomeSetting()));
                              },
                            ),
                          ],

                          if (userType == '2') ...[
                            const Divider(),
                            if (isLeader) ...[
                              ListTile(
                                leading: Icon(Icons.home_outlined,
                                    color: primaryColor),
                                title: const Text('ครัวเรือนของคุณ'),
                                trailing: const Icon(Icons.arrow_forward_ios,
                                    size: 16),
                                onTap: () async {
                                  // ดึง home_Code จาก SharedPreferences (ถ้ายังไม่มีตัวแปรใน state)
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  final homeCode =
                                      prefs.getInt('home_Code') ?? 0;

                                  if (!context.mounted) return;

                                  if (homeCode == 0) {
                                    changeLeader();
                                    // ยังไม่มีบ้าน → ไปหน้าสมัครบ้าน
                                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                          builder: (_) => RegisHome()),
                                      (_) => false,
                                    );
                                  } else {
                                    changeLeader();
                                    // มีบ้านแล้ว → ไปหน้าโฮมหรือ nav หลัก
                                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                                      MaterialPageRoute(builder: (_) => Nav()),
                                      (_) => false,
                                    );
                                  }
                                },
                              ),
                            ] else ...[
                              ListTile(
                                leading: Icon(Icons.home_outlined,
                                    color: primaryColor),
                                title: const Text('ครัวเรือน'),
                                trailing: const Icon(Icons.arrow_forward_ios,
                                    size: 16),
                                onTap: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => HomeSetting()));
                                },
                              ),
                              const Divider(),
                              ListTile(
                                leading: Icon(Icons.holiday_village_outlined,
                                    color: primaryColor),
                                title: const Text('ชุมชนของคุณ'),
                                trailing: const Icon(Icons.arrow_forward_ios,
                                    size: 16),
                                onTap: () {
                                  if (!context.mounted) return;
                                  changeLeader();
                                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                          builder: (_) => LeaderNav()),
                                      (_) => false,
                                    );
                                },
                              ),
                            ]
                          ],

                          const Divider(),
                          ListTile(
                            leading: Icon(Icons.phone_in_talk_outlined,
                                color: primaryColor),
                            title: const Text('ติดต่อเจ้าหน้าที่'),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (_) => SentReportPage()),
                                (route) => false,
                              );
                            },
                          ),
                          const Divider(),
                          ListTile(
                            title: const Text('ออกจากระบบ',
                                style: TextStyle(color: Colors.red)),
                            onTap: () async {
                              await AuthService.clearSession();
                              if (!context.mounted) return;
                              Navigator.of(context, rootNavigator: true)
                                  .pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (_) => LoginScreen()),
                                (_) => false,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
