import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'nav.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class RegisHome extends StatefulWidget {
  @override
  _RegisHomeState createState() => _RegisHomeState();
}

class _RegisHomeState extends State<RegisHome>
    with SingleTickerProviderStateMixin {
  final Color primaryColor = const Color(0xFF6FB188);
  late AnimationController _controller;
  final TextEditingController houseController = TextEditingController();
  File? _selectedImage;

  @override
  void initState() {
    super.initState();

    // สร้าง controller นับถอยหลัง 5 วินาที
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 5),
    )..reverse(from: 1.0); // เริ่มจาก 1 แล้วลดลง

    // หลัง 5 วิ ให้แสดง modal
    Future.delayed(Duration(seconds: 5), () {
      _showJoinModal(context);
    });
  }

  void _showFindJoinHouseholdModal(BuildContext context) {
    final TextEditingController houseController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'เข้าร่วมครัวเรือน',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: houseController,
                decoration: InputDecoration(
                  hintText: 'บ้านเลขที่',
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final homeNumber = houseController.text.trim();
                        if (homeNumber.isNotEmpty) {
                          findHome(context, homeNumber); // ส่งค่าไป API
                        } else {
                          AwesomeDialog(
                            context: context,
                            dialogType: DialogType.warning,
                            animType: AnimType.rightSlide,
                            title: 'แจ้งเตือน',
                            desc: 'กรุณากรอกบ้านเลขที่',
                            btnOkOnPress: () {},
                          ).show();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'ยืนยัน',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'ยกเลิก',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> findHome(BuildContext context, String homeNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final villageCode = prefs.getInt('village_code') ?? 0;

    const apiUrl =
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/findHome';

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['Home_number'] = homeNumber;
      request.fields['Village_Code'] = villageCode.toString();

      final response = await request.send();

      if (response.statusCode == 200) {
        final resBody = await response.stream.bytesToString();
        final Map<String, dynamic> data = jsonDecode(resBody);

        Navigator.of(context).pop(); // ปิด modal แรก
        _showJoinHouseholdModal(context, data); // ส่งข้อมูลทั้งหมด
      } else {
        final resBody = await response.stream.bytesToString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ค้นหาไม่สำเร็จ: $resBody')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  void _showJoinHouseholdModal(
      BuildContext context, Map<String, dynamic> homeData) {
    final String homeNumber = homeData['Home_number'] ?? '';
    final String? imageUrl = homeData['img'];

    final TextEditingController houseController =
        TextEditingController(text: homeNumber);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: (imageUrl != null && imageUrl.isNotEmpty)
                    ? NetworkImage(imageUrl)
                    : AssetImage('images/default.png') as ImageProvider,
                backgroundColor: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'บ้านเลขที่' + homeNumber,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        joinHome(context, homeData); // ส่งข้อมูลทั้งหมด
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text('เข้าร่วม',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      child:
                          Text('ยกเลิก', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  void _showCreateHouseholdModal(BuildContext context) {
    final TextEditingController houseController = TextEditingController();
    File? tempImage = _selectedImage;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: tempImage != null
                            ? FileImage(
                                tempImage!) // ✅ ใช้ tempImage! (non-nullable)
                            : AssetImage('images/default.png') as ImageProvider,
                        backgroundColor: Colors.grey[300],
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () async {
                            final pickedFile = await ImagePicker()
                                .pickImage(source: ImageSource.gallery);
                            if (pickedFile != null) {
                              final file = File(pickedFile.path);
                              setModalState(() => tempImage = file);
                              setState(() => _selectedImage = file);
                            }
                          },
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.white,
                            child:
                                Icon(Icons.edit, size: 16, color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'สร้างครัวเรือน',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: houseController,
                    decoration: InputDecoration(
                      hintText: 'บ้านเลขที่',
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final homeNumber = houseController.text.trim();
                            if (homeNumber.isNotEmpty) {
                              submitHome(context, homeNumber);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('กรุณากรอกบ้านเลขที่')));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          child: Text('สร้าง',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          child: Text('ยกเลิก',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> submitHome(BuildContext context, String homeNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final userCode = prefs.getInt('user_code') ?? 0;
    final villageCode = prefs.getInt('village_code') ?? 0;

    const apiUrl =
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/createHome';

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['Home_number'] = homeNumber;
      request.fields['User_Code'] = userCode.toString();
      request.fields['Village_Code'] = villageCode.toString();

      if (_selectedImage != null) {
        request.files.add(
            await http.MultipartFile.fromPath('img', _selectedImage!.path));
      }

      final response = await request.send();

      // ➜ เคสสำเร็จ
      if (response.statusCode == 200) {
        final resBody = await response.stream.bytesToString();
        final responseData = json.decode(resBody);
        final homeCode = responseData['home_Code'];

        await prefs.setInt('home_Code', homeCode);

        if (mounted) {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.success,
            animType: AnimType.scale,
            title: 'สำเร็จ',
            desc: 'สร้างครัวเรือนสำเร็จ',
            btnOkOnPress: () {
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => Nav()),
                (route) => false,
              );
            },
          ).show();
        }
        return;
      }

      // ➜ เคส 409 (เช่น บ้านเลขที่ซ้ำในชุมชน)
      if (response.statusCode == 409) {
        final resBody = await response.stream.bytesToString();
        String message = 'บ้านเลขที่นี้มีอยู่แล้วในชุมชนของคุณ';
        try {
          final obj = json.decode(resBody);
          if (obj is Map && obj['message'] != null) {
            message = obj['message'].toString();
          }
        } catch (_) {}
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.scale,
          title: 'ไม่สามารถสร้างได้',
          desc: message,
          btnOkOnPress: () {},
        ).show();
        return;
      }

      // ➜ เคสอื่น ๆ (422/500 ฯลฯ)
      final resBody = await response.stream.bytesToString();
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        title: 'ไม่สำเร็จ',
        desc: 'สร้างไม่สำเร็จ (${response.statusCode}): $resBody',
        btnOkOnPress: () {},
      ).show();
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        title: 'ข้อผิดพลาด',
        desc: 'เกิดข้อผิดพลาด: $e',
        btnOkOnPress: () {},
      ).show();
    }
  }

  Future<void> joinHome(
      BuildContext context, Map<String, dynamic> homeData) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final userCode = prefs.getInt('user_code') ?? 0;
    final villageCode = prefs.getInt('village_code') ?? 0;

    const apiUrl =
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/joinHome';

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.headers['Authorization'] = 'Bearer $token';

      final String homeCode = homeData['home_Code'].toString();
      final String homeNumber = homeData['Home_number'];

      request.fields['home_Code'] = homeCode;
      request.fields['Home_number'] = homeNumber;
      request.fields['User_Code'] = userCode.toString();
      request.fields['Village_Code'] = villageCode.toString();

      final response = await request.send();

      if (response.statusCode == 200) {
        final resBody = await response.stream.bytesToString();
        final responseData = json.decode(resBody);
        final homeCode = responseData['home_Code'];
        print('HOMECode: $homeCode'); // ✅ ป้องกัน error

        await prefs.setInt('home_Code', int.parse(homeCode));

        final savedHomeCode = prefs.getInt('home_Code');
        print('Saved home_Code in prefs: $savedHomeCode');

        if (mounted) {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.success,
            animType: AnimType.bottomSlide,
            title: 'สำเร็จ',
            desc: 'เข้าร่วมครัวเรือนสำเร็จ',
            btnOkOnPress: () {
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => Nav()),
                (route) => false,
              );
            },
          ).show();
        }
      } else {
        final resBody = await response.stream.bytesToString();
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'ไม่สำเร็จ',
          desc: 'เข้าร่วมไม่สำเร็จ: $resBody',
          btnOkOnPress: () {},
        ).show();
      }
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        title: 'ข้อผิดพลาด',
        desc: 'เกิดข้อผิดพลาด: $e',
        btnOkOnPress: () {},
      ).show();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Low Carbon Community'),
        backgroundColor: primaryColor,
      ),
      resizeToAvoidBottomInset: true, // ✅ เปิดให้เลื่อนหลบ keyboard
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 40), // เพิ่ม margin ให้ scroll ได้
              Image.asset('images/logo.png', width: 300, height: 300),
              const SizedBox(height: 12),
              Text(
                'เริ่มต้นสู่ชุมชนสีเขียวของคุณ!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'ร่วมติดตามและลดการปล่อยก๊าซเรือนกระจกจากกิจกรรมในชีวิตประจำวันของคุณ เช่น การเดินทางและการใช้พลังงาน พร้อมสร้างความเปลี่ยนแปลงที่ยั่งยืนให้กับชุมชนของเรา',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showJoinModal(context),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.home, size: 40, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: _controller.value,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    minHeight: 8,
                  );
                },
              ),
              const SizedBox(
                  height: 40), // เพิ่ม padding ด้านล่าง กันชน keyboard
            ],
          ),
        ),
      ),
    );
  }

  void _showJoinModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('เข้าร่วมครัวเรือน'),
          content: Text('คุณมีครัวเรือนที่ต้องการเข้าร่วมหรือไม่?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // ปิด modal แรก
                _showCreateHouseholdModal(context); // เปิด modal สร้างครัวเรือน
              },
              child: Text('ยังไม่มี'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // ปิด modal แรก
                _showFindJoinHouseholdModal(
                    context); // เปิด modal สร้างครัวเรือน
              },
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              child: Text('มีอยู่แล้ว', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
