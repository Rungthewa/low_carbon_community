import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'leaderActivity.dart';
import 'api.dart';

class CreateActivityPage extends StatefulWidget {
  final int? activityCode;
  final bool isEdit;
  const CreateActivityPage({
    super.key,
    this.activityCode,
    this.isEdit = false,
  });

  @override
  State<CreateActivityPage> createState() => _CreateActivityPageState();
}

class _CreateActivityPageState extends State<CreateActivityPage> {
  final Color primaryColor = const Color(0xFF6FB188);
  final Color backgroundColor = const Color(0xFFBDE2CB);
  List<Map<String, dynamic>> treeList = [];
  List<String> selectedTrees = [];
  List<int> selectedTreeCodes = [];
  Map<int, String> treeCountMap = {};
  Map<int, String> treeDeadMap = {};
  int activityStatus = 0;

  final nameController = TextEditingController();
  final treeTypeController = TextEditingController();
  final treeCountController = TextEditingController();
  final detailController = TextEditingController();
  final wantCountController = TextEditingController();
  final trashWeightController = TextEditingController();

  DateTime? activityDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  String selectedType = 'ปลูกต้นไม้';
  final activityTypes = ['ปลูกต้นไม้', 'เก็บขยะ'];

  @override
  void initState() {
    super.initState();
    loadTreeList();
    if (widget.isEdit && widget.activityCode != null) {
      loadActivityData(widget.activityCode!);
    }
  }

  Future<void> loadTreeList() async {
    try {
      final res = await ApiClient.getRequest('/TreeList');
      if (res.statusCode == 200) {
        final jsonData = jsonDecode(res.body);
        setState(() {
          treeList = (jsonData as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      } else {
        debugPrint('Tree list failed: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('Error loading tree list: $e');
    }
  }

  Future<void> createActivity() async {
    if (nameController.text.isEmpty || activityDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วน')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userCode = prefs.getInt('user_code');
    final villageCode = prefs.getInt('village_code');
    if (userCode == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ไม่พบข้อมูลผู้ใช้')));
      return;
    }

    final start = startTime != null
        ? '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}'
        : '';
    final end = endTime != null
        ? '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}'
        : '';

    final treeDetails = selectedTreeCodes
        .map((code) => {
              'tree_code': code,
              'count': int.tryParse(treeCountMap[code] ?? '0') ?? 0,
            })
        .toList();

    final body = {
      'user_code': userCode,
      'village_code': villageCode,
      'activity_name': nameController.text,
      'activity_type': selectedType,
      'detail': detailController.text,
      'want_count': wantCountController.text,
      'activity_date': DateFormat('yyyy-MM-dd').format(activityDate!),
      'start_time': start,
      'end_time': end,
      'tree_details': treeDetails,
    };

    try {
      final res = await ApiClient.postRequest('/createActivity', payload: body);
      if (res.statusCode == 200) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.scale,
          title: 'สำเร็จ',
          desc: 'บันทึกกิจกรรมเรียบร้อยแล้ว',
          btnOkOnPress: () {
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => LeaderActivityPage()));
          },
        ).show();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาด: ${res.body}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เชื่อมต่อไม่สำเร็จ: $e')));
    }
  }

  Future<void> loadActivityData(int activityCode) async {
    try {
      final res =
          await ApiClient.getRequest('/getActivityByCode/$activityCode');
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final data = json['data'];
        setState(() {
          nameController.text = data['activity_name'];
          detailController.text = data['detail'];
          wantCountController.text = '${data['want_count']}';
          selectedType = data['activity_type'];
          activityDate = DateTime.parse(data['activity_date']);
          startTime = _parseTime(data['start_time']);
          endTime = _parseTime(data['end_time']);
          activityStatus = (data['status'] ?? 0) as int;
          final List treeDetails = (data['tree_details'] ?? []) as List;
          selectedTreeCodes =
              treeDetails.map<int>((e) => e['tree_code'] as int).toList();
          treeCountMap.clear();
          treeDeadMap.clear();
          for (final t in treeDetails) {
            final code = t['tree_code'] as int;
            treeCountMap[code] = '${t['count'] ?? 0}';
            treeDeadMap[code] = '${t['dead_count'] ?? 0}';
          }
          print(treeCountMap);
        });
      } else {
        debugPrint('โหลดกิจกรรมล้มเหลว: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('เกิดข้อผิดพลาด: $e');
    }
  }

  TimeOfDay _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return TimeOfDay.now();
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> updateActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final userCode = prefs.getInt('user_code');
    final villageCode = prefs.getInt('village_code');
    if (userCode == null || villageCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบข้อมูลผู้ใช้หรือหมู่บ้าน')));
      return;
    }

    final start = startTime != null
        ? '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}'
        : '';
    final end = endTime != null
        ? '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}'
        : '';

    final treeDetails = selectedTreeCodes
        .map((code) => {
              'tree_code': code,
              'count': int.tryParse(treeCountMap[code] ?? '0') ?? 0,
              'dead_count': int.tryParse(treeDeadMap[code] ?? '0') ?? 0,
            })
        .toList();

    final body = {
      'activity_code': widget.activityCode,
      'user_code': userCode,
      'village_code': villageCode,
      'activity_name': nameController.text,
      'activity_type': selectedType,
      'detail': detailController.text,
      'want_count': wantCountController.text,
      'activity_date': DateFormat('yyyy-MM-dd').format(activityDate!),
      'start_time': start,
      'end_time': end,
      'tree_details': treeDetails,
    };

    try {
      final res = await ApiClient.postRequest('/updateActivity', payload: body);
      if (res.statusCode == 200) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.scale,
          title: 'สำเร็จ',
          desc: 'แก้ไขกิจกรรมเรียบร้อยแล้ว',
          btnOkOnPress: () {
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => LeaderActivityPage()));
          },
        ).show();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาด: ${res.body}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เชื่อมต่อไม่สำเร็จ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: primaryColor,
        centerTitle: true,
        title: const Text('LOW CARBON COMMUNITY'),
      ),
      body: Stack(
        children: [
          Container(height: screenSize.height, color: backgroundColor),

          // กล่องสีขาวด้านบน
          Positioned(
            top: screenSize.height * 0.08,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
            ),
          ),

          // เนื้อหาทั้งหมดของหน้า
          Positioned.fill(
            child: Column(
              children: [
                const SizedBox(height: 18),
                Text(
                  widget.isEdit ? 'แก้ไขกิจกรรม' : 'สร้างกิจกรรม',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('ชื่อกิจกรรม'),
                        _buildTextField(nameController, 'ระบุชื่อ'),
                        _buildLabel('ประเภทกิจกรรม'),
                        DropdownButtonFormField<String>(
                          value: selectedType,
                          items: activityTypes
                              .map((type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type),
                                  ))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => selectedType = val!),
                          decoration: _inputDecoration(),
                        ),
                        const SizedBox(height: 16),
                        if (selectedType == "ปลูกต้นไม้") ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('ชนิดต้นไม้'),
                              _buildTreeMultiSelect(),
                              const SizedBox(height: 5), // ระยะห่างระหว่างแถว

                              _buildLabel('จำนวนต้นไม้'),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child:
                                        _buildTreeCountInputs(), // หรือใส่ TextField ตรงนี้ก็ได้
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                        if (selectedType == "เก็บขยะ") ...[
                          _buildLabel('จำนวนขยะที่ต้องการเก็บ'),
                          _buildTextField(trashWeightController, 'กิโลกรัม'),
                        ],
                        _buildLabel('รายละเอียด'),
                        _buildTextField(detailController, 'รายละเอียด',
                            maxLines: 3),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('จำนวนคนเข้าร่วม'),
                                  _buildTextField(wantCountController, 'จำนวน'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('วันที่ทำกิจกรรม'),
                                  GestureDetector(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        setState(() => activityDate = picked);
                                      }
                                    },
                                    child: AbsorbPointer(
                                      child: TextFormField(
                                        decoration: _inputDecoration(
                                          icon: Icons.calendar_today,
                                          hintText: activityDate != null
                                              ? DateFormat('dd/MM/yyyy')
                                                  .format(activityDate!)
                                              : 'วัน/เดือน/ปี',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('ระยะเวลาเริ่ม'),
                                  GestureDetector(
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.now(),
                                      );
                                      if (picked != null) {
                                        setState(() => startTime = picked);
                                      }
                                    },
                                    child: AbsorbPointer(
                                      child: TextFormField(
                                        decoration: _inputDecoration(
                                          icon: Icons.access_time,
                                          hintText:
                                              startTime?.format(context) ??
                                                  'ระยะเวลา',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('ระยะเวลาสิ้นสุด'),
                                  GestureDetector(
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.now(),
                                      );
                                      if (picked != null) {
                                        setState(() => endTime = picked);
                                      }
                                    },
                                    child: AbsorbPointer(
                                      child: TextFormField(
                                        decoration: _inputDecoration(
                                          icon: Icons.access_time,
                                          hintText: endTime?.format(context) ??
                                              'ระยะเวลา',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              // แก้ไขปุ่มสร้างด้านล่างให้เปลี่ยนไปตาม isEdit
                              child: ElevatedButton(
                                onPressed: widget.isEdit
                                    ? updateActivity
                                    : createActivity,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Text(
                                  widget.isEdit ? 'แก้ไข' : 'สร้าง',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            LeaderActivityPage()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color.fromARGB(255, 255, 107, 96),
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text(
                                  'ยกเลิก',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: _inputDecoration(hintText: hint),
    );
  }

  InputDecoration _inputDecoration({String? hintText, IconData? icon}) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.grey[100],
      suffixIcon: icon != null ? Icon(icon) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildTreeMultiSelect() {
    return GestureDetector(
      onTap: () {
        if (treeList.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('กำลังโหลดข้อมูลต้นไม้ หรือไม่พบข้อมูล')),
          );
          return;
        }

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setModalState) => Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'เลือกชนิดต้นไม้',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 300,
                      child: ListView(
                        children: treeList.map((tree) {
                          final int code =
                              int.parse(tree['tree_Code'].toString());
                          final String name = tree['tree_Name'];
                          final bool isSelected =
                              selectedTreeCodes.contains(code);

                          return CheckboxListTile(
                            title: Text(name),
                            value: isSelected,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true &&
                                    !selectedTreeCodes.contains(code)) {
                                  selectedTreeCodes.add(code);
                                } else if (val == false &&
                                    selectedTreeCodes.contains(code)) {
                                  selectedTreeCodes.remove(code);
                                }
                              });
                              setState(() {}); // 👉 เพื่ออัปเดต label ด้านนอก
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('ตกลง'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedTreeCodes.isEmpty
                    ? 'เลือกชนิดต้นไม้'
                    : _getSelectedTreeNames(),
                style: const TextStyle(color: Colors.black),
              ),
            ),
            const Icon(Icons.arrow_drop_down)
          ],
        ),
      ),
    );
  }

  String _getSelectedTreeNames() {
    final selectedNames = treeList
        .where((tree) =>
            selectedTreeCodes.contains(int.parse(tree['tree_Code'].toString())))
        .map((tree) => tree['tree_Name'].toString())
        .toList();

    return selectedNames.join(', ');
  }

  Widget _buildTreeCountInputs() {
    return Column(
      children: selectedTreeCodes.map((code) {
        final tree = treeList.firstWhere((t) => t['tree_Code'] == code);
        final name = tree['tree_Name'];
        final locked = activityStatus == 1; // ✅ ถ้าปิดกิจกรรมแล้ว

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 0),
              // จำนวน (count) — ถูกล็อกเมื่อ activityStatus == 1
              Expanded(
                flex: 1,
                child: TextFormField(
                  initialValue: treeCountMap[code] ?? '',
                  enabled: !locked, // 🔒 ปิดแก้ไขเมื่อปิดกิจกรรม
                  readOnly: locked,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'จำนวน',
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    if (!locked) {
                      setState(() {
                        treeCountMap[code] = val;
                      });
                    }
                  },
                ),
              ),

              // แสดงช่อง dead_count เฉพาะเมื่อกิจกรรมถูกปิด (status == 1)
              if (locked) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    initialValue: treeDeadMap[code] ?? '0',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'ตาย',
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        treeDeadMap[code] = val;
                      });
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}
