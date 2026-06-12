import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'AccoutSetting.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class UpdateAccountPage extends StatefulWidget {
  @override
  _UpdateAccountPageState createState() => _UpdateAccountPageState();
}

class _UpdateAccountPageState extends State<UpdateAccountPage> {
  final Color primaryColor = Color(0xFF6FB188);
  final _formKey = GlobalKey<FormState>();
  File? _profileImage;
  String? profileImageUrl;

  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController telController = TextEditingController();

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserInfo();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    telController.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      cursorColor: primaryColor,
      decoration: InputDecoration(
        labelText: label,
        hintText: 'กรอก$label',
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey[100],
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      ),
      validator: validator,
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
      _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final userCode = prefs.getInt('user_code') ?? 0;

    if (_profileImage == null) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        title: 'ไม่พบรูปภาพ',
        desc: 'กรุณาเลือกรูปก่อนอัปโหลด',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    try {
      final uri = Uri.parse(
          'https://student.crru.ac.th/651463011/LowCarbonAPI/api/uploadProfileImage/$userCode');
      var request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..files
            .add(await http.MultipartFile.fromPath('img', _profileImage!.path));

      var response = await request.send();
      final responseBody = await response.stream.bytesToString();
      print('RESPONSE STATUS: ${response.statusCode}');
      print('RESPONSE BODY: $responseBody');

      if (response.statusCode == 200) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          title: 'อัปโหลดสำเร็จ',
          desc: 'อัปเดตรูปโปรไฟล์แล้ว',
          btnOkOnPress: () {},
        ).show();
        fetchUserInfo(); // รีโหลดข้อมูลโปรไฟล์
      } else {
        // ลอง parse body เป็น json หากได้
        String errorMsg = 'อัปโหลดรูปไม่สำเร็จ';
        try {
          final data = json.decode(responseBody);
          if (data['message'] != null) errorMsg = data['message'];
        } catch (_) {}

        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'ผิดพลาด',
          desc: errorMsg,
          btnOkOnPress: () {},
        ).show();
      }
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        title: 'ข้อผิดพลาด',
        desc: 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้\n$e',
        btnOkOnPress: () {},
      ).show();
    }
  }

  Future<void> fetchUserInfo() async {
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
        if (!mounted) return;

        setState(() {
          nameController.text = data['User_Name'] ?? '';
          emailController.text = data['email'] ?? '';
          telController.text = data['tel'] ?? '';
          profileImageUrl = data['user_img'];
          isLoading = false;
        });
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> updateAccount() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus(); // ปิดคีย์บอร์ด

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final userCode = prefs.getInt('user_code') ?? 0;

    final url = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/updateAccount/$userCode');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'User_Name': nameController.text,
          'email': emailController.text,
          'tel': telController.text,
        }),
      );

      if (response.statusCode == 200) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.scale,
          title: 'สำเร็จ',
          desc: 'อัปเดตข้อมูลสำเร็จ',
          btnOkText: 'ตกลง',
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
          animType: AnimType.rightSlide,
          title: 'ผิดพลาด',
          desc: 'ไม่สามารถอัปเดตข้อมูลได้',
          btnOkOnPress: () {},
        ).show();
      }
    } catch (e) {
      print("Update failed: $e");
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        animType: AnimType.leftSlide,
        title: 'เชื่อมต่อไม่ได้',
        desc: 'เกิดข้อผิดพลาดในการเชื่อมต่อ',
        btnOkOnPress: () {},
      ).show();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text('แก้ไขข้อมูลโปรไฟล์'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      children: [
                        Center(
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundImage: _profileImage != null
                                      ? FileImage(_profileImage!)
                                      : (profileImageUrl != null &&
                                              profileImageUrl!.isNotEmpty)
                                          ? NetworkImage(profileImageUrl!)
                                              as ImageProvider
                                          : AssetImage(
                                              'images/default_profile.png'),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 4,
                                child: GestureDetector(
                                  onTap: _pickImage,
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: primaryColor,
                                    child: Icon(Icons.edit,
                                        color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Divider(thickness: 1.5),
                        const SizedBox(height: 16),

                        // ชื่อ
                        _buildTextField(
                          controller: nameController,
                          label: 'ชื่อผู้ใช้',
                          icon: Icons.person,
                          validator: (value) =>
                              value!.isEmpty ? 'กรุณากรอกชื่อ' : null,
                        ),

                        // อีเมล
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: emailController,
                          label: 'อีเมล',
                          icon: Icons.email,
                          inputType: TextInputType.emailAddress,
                          validator: (value) =>
                              value!.isEmpty ? 'กรุณากรอกอีเมล' : null,
                        ),

                        // โทรศัพท์
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: telController,
                          label: 'เบอร์โทรศัพท์',
                          icon: Icons.phone,
                          inputType: TextInputType.phone,
                          validator: (value) =>
                              value!.isEmpty ? 'กรุณากรอกเบอร์โทร' : null,
                        ),

                        const SizedBox(height: 32),

                        // ปุ่มบันทึก
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: updateAccount,
                            icon: Icon(Icons.save ,color: Colors.white,),
                            label: Text('บันทึก',style: TextStyle(color: Colors.white),),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ปุ่มย้อนกลับ
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey),
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                    builder: (context) => AccountSettingPage()),
                              );
                            },
                            icon: Icon(Icons.arrow_back ,color: primaryColor,),
                            label: Text('ย้อนกลับ', style: TextStyle(color: primaryColor)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
