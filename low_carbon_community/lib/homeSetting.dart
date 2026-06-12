import 'package:flutter/material.dart';
import 'AccoutSetting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'AccoutSetting.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'regisHome.dart';

class HomeSetting extends StatefulWidget {
  @override
  _HomeSettingState createState() => _HomeSettingState();
}

class _HomeSettingState extends State<HomeSetting> {
  final Color primaryColor = Color(0xFF6FB188);
  String homeNumber = '-';
  double co2 = 0;
  double ch4 = 0;
  double other = 0;
  double totalEmission = 0;
  bool isLoading = true;
  String? imageUrl;
  ImageProvider<Object> getProfileImage() {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return NetworkImage(imageUrl!);
    } else {
      return AssetImage('images/default.png');
    }
  }

  List<dynamic> members = [];

  @override
  void initState() {
    super.initState();
    fetchHomeSettingData();
  }

  Future<void> fetchHomeSettingData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final homeCode = prefs.getInt('home_Code') ?? 0;

    final url = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/getHomeMembers/$homeCode');

    try {
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          members = data;
          homeNumber = data.first['Home_number'] ?? '-';
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Fetch error: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> exitHome() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final userCode = prefs.getInt('user_code') ?? 0;
    final homeCode = prefs.getInt('home_Code') ?? 0;

    const apiUrl = 'https://student.crru.ac.th/651463011/LowCarbonAPI/api/exitHome';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'User_Code': userCode,'home_Code': homeCode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          await prefs.remove('home_Code');
          if (mounted) {
            AwesomeDialog(
              context: context,
              dialogType: DialogType.success,
              title: 'สำเร็จ',
              desc: 'ออกจากครัวเรือนเรียบร้อยแล้ว',
              btnOkOnPress: () {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => RegisHome()),
                  (route) => false,
                );
              },
            ).show();
          }
        } else {
          _showErrorDialog('ออกจากครัวเรือนไม่สำเร็จ');
        }
      } else {
        _showErrorDialog('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้');
      }
    } catch (e) {
      _showErrorDialog('เกิดข้อผิดพลาด: $e');
    }
  }

  void _showErrorDialog(String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      title: 'ผิดพลาด',
      desc: message,
      btnOkOnPress: () {},
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

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
        title: Text('LOW CARBON COMMUNITY'),
      ),
      body: Stack(
        children: [
          Container(height: screenSize.height, color: Color(0xFFBDE2CB)),
          Positioned(
            top: screenSize.height * 0.08,
            left: 0,
            right: 0,
            child: Container(
              height: screenSize.height * 0.92,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : Column(
                    children: [
                      const SizedBox(height: 24),
                      // CircleAvatar อยู่ตรงกลาง
                      Align(
                        alignment: Alignment.center,
                        child: CircleAvatar(
                          radius: 40,
                          backgroundImage: getProfileImage(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Text(
                              'บ้านเลขที่',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            Spacer(),
                            ElevatedButton.icon(
                              onPressed: () {
                                AwesomeDialog(
                                  context: context,
                                  dialogType: DialogType.question,
                                  animType: AnimType.bottomSlide,
                                  title: 'ออกจากครัวเรือน',
                                  desc: 'คุณต้องการออกจากครัวเรือนใช่หรือไม่?',
                                  btnCancelOnPress: () {},
                                  btnOkOnPress: () async {
                                    await exitHome();
                                  },
                                ).show();
                              },
                              icon: Icon(Icons.logout, size: 16),
                              label: Text('ออกจากครัวเรือน',
                                  style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: StadiumBorder(),
                                elevation: 2,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.9,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        margin: EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Color(0xFFD7EDD9),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          homeNumber,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),

                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'สมาชิก',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor),
                            ),
                            Text(
                              'จำนวน ${members.length} ท่าน',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: members
                                .map((member) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _buildMemberItem(member),
                                    ))
                                .toList(),
                          )),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberItem(Map<String, dynamic> member) {
    final String name = member['User_Name'] ?? '-';
    final String? imageUrl = member['user_img'];
    final bool isLeader = (member['status'].toString() == '0'); // หัวหน้า

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                    ? NetworkImage(imageUrl)
                    : AssetImage('images/user.png') as ImageProvider,
              ),
              if (isLeader)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.green,
                    child: Icon(Icons.check, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
