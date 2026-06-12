// (นำส่วน import/คลาสมาเหมือนเดิม)
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'AddElectricModal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'AddCo2.dart';
import 'AllHistory.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class ElecItemPage extends StatefulWidget {
  @override
  _ElecItemPageState createState() => _ElecItemPageState();
}

class _ElecItemPageState extends State<ElecItemPage> {
  final Color primaryColor = const Color(0xFF6FB188);
  List<Map<String, dynamic>> itemTypes = [];
  List<Map<String, dynamic>> monthlyCheck = [];
  int? selectedItem;

  bool _fabOpen = false;
  bool _submitting = false;
  final TextEditingController _kwhController = TextEditingController();
  int _selMonth = DateTime.now().month;
  int _selYear = DateTime.now().year;
  List<int> get _yearOptions {
    final nowY = DateTime.now().year;
    return List.generate(7, (i) => nowY - 3 + i);
  }

  // ชื่อเดือนภาษาไทย
  List<Map<String, dynamic>> _monthsTH = [
    {'val': 1, 'label': 'มกราคม'},
    {'val': 2, 'label': 'กุมภาพันธ์'},
    {'val': 3, 'label': 'มีนาคม'},
    {'val': 4, 'label': 'เมษายน'},
    {'val': 5, 'label': 'พฤษภาคม'},
    {'val': 6, 'label': 'มิถุนายน'},
    {'val': 7, 'label': 'กรกฎาคม'},
    {'val': 8, 'label': 'สิงหาคม'},
    {'val': 9, 'label': 'กันยายน'},
    {'val': 10, 'label': 'ตุลาคม'},
    {'val': 11, 'label': 'พฤศจิกายน'},
    {'val': 12, 'label': 'ธันวาคม'},
  ];
  // final wattController = TextEditingController();
  final sizeController = TextEditingController();
  final locationController = TextEditingController();
  final monthlyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchItemTypes();
    fetchHomeItems();
  }

  Future<void> fetchItemTypes() async {
    final response = await http.get(Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/getItemType'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        itemTypes = List<Map<String, dynamic>>.from(data);
        selectedItem =
            itemTypes.isNotEmpty ? itemTypes.first['Item_type_Code'] : null;
      });
    } else {
      print("โหลด ItemType ไม่สำเร็จ");
    }
  }

  Future<bool> checkHaveMonthly({required int month, required int year}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final homeCode = prefs.getInt('home_Code') ?? 0;

    final response = await http.post(
      Uri.parse(
          'https://student.crru.ac.th/651463011/LowCarbonAPI/api/checkMonthly'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'home_Code': homeCode,
        'month': month,
        'year': year,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      bool exists = false;
      if (data is List && data.isNotEmpty) {
        _kwhController.text =
            (data.first['Distance_time'] ?? data.first['kwh'] ?? '').toString();
        exists = true;
      } else if (data is Map && data.isNotEmpty) {
        _kwhController.text =
            (data['Distance_time'] ?? data['kwh'] ?? '').toString();
        exists = true;
      } else {
        _kwhController.clear();
        exists = false;
      }
      return exists;
    } else {
      print(
          "โหลด monthlyCheck ไม่สำเร็จ: ${response.statusCode} ${response.body}");
      _kwhController.clear();
      return false;
    }
  }

  void _toggleFab() => setState(() => _fabOpen = !_fabOpen);

  void _openAddElectricDialog() {
    // ใช้ dialog เดิมของคุณ (AddElectricModal)
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        content: Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: Material(
              borderRadius: BorderRadius.circular(30),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.55,
                    ),
                    child: AddElectricModal(
                      itemTypes: itemTypes,
                      selectedItem: selectedItem,
                      sizeController: sizeController,
                      locationController: locationController,
                      onItemChanged: (value) =>
                          setState(() => selectedItem = value),
                      onSubmitted: fetchHomeItems,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openMonthlyEnergyDialog() async {
    // โหลดค่าปัจจุบันของเดือน/ปีเริ่มต้น
    bool hasMonthly = await checkHaveMonthly(month: _selMonth, year: _selYear);

    int tempMonth = _selMonth;
    int tempYear = _selYear;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> _refreshByMonthYear(int m, int y) async {
              // รีโหลดค่าเมื่อเปลี่ยนเดือน/ปี และบอกว่าเดิมมีไหม
              final exist = await checkHaveMonthly(month: m, year: y);
              setDialogState(() {
                hasMonthly = exist;
              });
            }

            final actionLabel = hasMonthly ? 'แก้ไข' : 'เพิ่ม';

            return AlertDialog(
              title: Text(
                  hasMonthly ? 'แก้ไขค่าไฟรายเดือน' : 'เพิ่มค่าไฟรายเดือน'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        flex: 10,
                        child: DropdownButtonFormField<int>(
                          value: tempMonth,
                          decoration: InputDecoration(
                            labelText: 'เดือน',
                            filled: true,
                            fillColor: const Color(0xFFE0E0E0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black),
                          dropdownColor: const Color(0xFFE0E0E0),
                          items: _monthsTH
                              .map((m) => DropdownMenuItem<int>(
                                    value: m['val'] as int,
                                    child: Text(m['label'] as String),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            tempMonth = v;
                            _refreshByMonthYear(tempMonth, tempYear);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        flex: 7,
                        child: DropdownButtonFormField<int>(
                          value: tempYear,
                          decoration: InputDecoration(
                            labelText: 'ปี',
                            filled: true,
                            fillColor: const Color(0xFFE0E0E0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black),
                          dropdownColor: const Color(0xFFE0E0E0),
                          items: _yearOptions
                              .map((y) => DropdownMenuItem<int>(
                                    value: y,
                                    child: Text(y.toString()),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            tempYear = v;
                            _refreshByMonthYear(tempMonth, tempYear);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _kwhController,
                    label: 'ค่าพลังงานไฟฟ้า (kWh)',
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? 'กรุณากรอกค่าพลังงานไฟฟ้า'
                            : null,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('ปิด'),
                ),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () async {
                          // commit เดือน/ปี ที่เลือกกลับไป state หลัก
                          setState(() {
                            _selMonth = tempMonth;
                            _selYear = tempYear;
                          });
                          await _submitMonthlyEnergyWithMonthYear(
                            month: _selMonth,
                            year: _selYear,
                            isEdit:
                                hasMonthly, // << ส่งสถานะว่ากำลังแก้ไขหรือเพิ่ม
                          );
                        },
                  child: Text(actionLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitMonthlyEnergyWithMonthYear({
    required int month,
    required int year,
    required bool isEdit, // << เพิ่มพารามิเตอร์
  }) async {
    if (_kwhController.text.trim().isEmpty) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        animType: AnimType.scale,
        title: 'กรุณากรอกข้อมูล',
        desc: 'กรุณากรอก kWh',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userCode = prefs.getInt('user_code') ?? 0;
    if (userCode == 0) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.scale,
        title: 'ไม่พบข้อมูล',
        desc: 'ไม่พบรหัสผู้ใช้',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    final kwh = _kwhController.text.trim();

    setState(() => _submitting = true);
    try {
      final res = await http.post(
        Uri.parse(
            'https://student.crru.ac.th/651463011/LowCarbonAPI/api/addMonthlyEnergy'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'User_Code': userCode.toString(),
          'kwh': kwh,
          'month': month.toString(),
          'year': year.toString(),
          // ถ้าหลังบ้านอยากรู้ชัด ๆ ว่าเป็นแก้ไข ก็ส่ง flag เพิ่มได้ เช่น:
          'mode': isEdit ? 'update' : 'create',
        },
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        Navigator.of(context, rootNavigator: true).pop(); // ปิด dialog
        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.scale,
          title: 'สำเร็จ',
          desc: isEdit
              ? 'แก้ไขพลังงานรายเดือนสำเร็จ'
              : 'บันทึกพลังงานรายเดือนสำเร็จ',
          btnOkOnPress: () {},
        ).show();
      } else {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.scale,
          title: isEdit ? 'แก้ไขไม่สำเร็จ' : 'บันทึกไม่สำเร็จ',
          desc: res.body.isNotEmpty ? res.body : 'เกิดข้อผิดพลาดจากเซิร์ฟเวอร์',
          btnOkOnPress: () {},
        ).show();
      }
    } catch (e) {
      if (!mounted) return;
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.scale,
        title: 'ข้อผิดพลาดเครือข่าย',
        desc: '$e',
        btnOkOnPress: () {},
      ).show();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _openEditElectricDialog(Map<String, dynamic> item) {
    // เติมค่าเริ่มต้นลง controller/ตัวเลือก
    final int? currentType = item['Item_type_Code'];
    final String currentSize = (item['size'] ?? '').toString();
    final String currentLocation =
        (item['location_name'] ?? item['location'] ?? '').toString();
    final String currentRadio =
        (item['type'] ?? 'N').toString(); // 'N'/'I' ตามระบบเดิม

    // sync ไป state หลักให้ dropdown ขึ้นตัวเดิม
    setState(() {
      selectedItem = currentType;
      sizeController.text = currentSize;
      locationController.text = currentLocation;
    });

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        content: Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: Material(
              borderRadius: BorderRadius.circular(30),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.55,
                    ),
                    child: AddElectricModal(
                      itemTypes: itemTypes,
                      selectedItem: selectedItem,
                      sizeController: sizeController,
                      locationController: locationController,
                      onItemChanged: (value) =>
                          setState(() => selectedItem = value),
                      onSubmitted: () {
                        Navigator.pop(context); // ปิด modal
                        fetchHomeItems(); // รีเฟรชรายการ
                      },

                      // ⬇️ พารามิเตอร์ “เพิ่ม” สำหรับโหมดแก้ไข
                      isEdit: true,
                      editingItemCode: (item['item_Code'] ?? item['Item_Code']),
                      initialRadio: currentRadio, // 'N' หรือ 'I'
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- ฟังก์ชันลบรายการ ----------
  Future<void> _deleteHomeItem(Map<String, dynamic> item) async {
    final code = item['item_Code'] ?? item['Item_Code'];
    if (code == null) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.scale,
        title: 'ไม่พบรหัสรายการ',
        desc: 'ไม่สามารถลบได้เนื่องจากไม่พบรหัสรายการ',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    // ยืนยันการลบ
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: 'ลบรายการ',
      desc: 'ต้องการลบรายการนี้หรือไม่?',
      btnCancelText: 'ไม่',
      btnOkText: 'ใช่',
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        setState(() => _submitting = true);
        try {
          final url = Uri.parse(
              'https://student.crru.ac.th/651463011/LowCarbonAPI/api/deleteHomeItem');
          final res = await http.post(url,
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: {'item_Code': code.toString()});

          if (!mounted) return;

          if (res.statusCode == 200) {
            AwesomeDialog(
              context: context,
              dialogType: DialogType.success,
              animType: AnimType.scale,
              title: 'ลบสำเร็จ',
              desc: 'ลบรายการเรียบร้อยแล้ว',
              btnOkOnPress: () {},
            ).show();
            await fetchHomeItems();
          } else {
            AwesomeDialog(
              context: context,
              dialogType: DialogType.error,
              animType: AnimType.scale,
              title: 'ลบไม่สำเร็จ',
              desc: res.body.isNotEmpty
                  ? res.body
                  : 'เกิดข้อผิดพลาดจากเซิร์ฟเวอร์',
              btnOkOnPress: () {},
            ).show();
          }
        } catch (e) {
          if (!mounted) return;
          AwesomeDialog(
            context: context,
            dialogType: DialogType.error,
            animType: AnimType.scale,
            title: 'ข้อผิดพลาดเครือข่าย',
            desc: '$e',
            btnOkOnPress: () {},
          ).show();
        } finally {
          if (mounted) setState(() => _submitting = false);
        }
      },
    ).show();
  }

  Widget _roundActionButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.white,
      elevation: 10,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 50,
          height: 50,
          child: Icon(icon, size: 24, color: iconColor ?? primaryColor),
        ),
      ),
    );
  }

  Widget _actionRow({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    TextStyle? labelStyle,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
        ),
        _roundActionButton(icon: icon, onTap: onTap, iconColor: iconColor),
      ],
    );
  }

  List<Map<String, dynamic>> homeItems = [];

  Future<void> fetchHomeItems() async {
    final prefs = await SharedPreferences.getInstance();
    final homeCode = prefs.getInt('home_Code') ?? 0;

    final url = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/getHomeItem/$homeCode');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          homeItems = List<Map<String, dynamic>>.from(data);
          print(homeItems);
        });
      } else {
        setState(() {
          homeItems = [];
        });
      }
    } catch (e) {
      print("ไม่สามารถโหลดข้อมูลเครื่องใช้ไฟฟ้า: $e");
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      cursorColor: primaryColor,
      decoration: InputDecoration(
        labelText: label,
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

  // helper
  Future<void> _goToHistory(String type) async {
    if (_fabOpen) _toggleFab(); // ปิด FAB ก่อน
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HistoryPage(searchType: type)),
    );
    // (ออปชัน) กลับมาแล้วยังปิด FAB ให้ชัวร์
    if (_fabOpen) _toggleFab();
  }

  // ปุ่มกลมเงาๆ

// เปิดเมนูด่วนแบบในรูป

// ส่งค่า Monthly Energy ไปหลังบ้าน
  Future<void> _submitMonthlyEnergy() async {
    if (_kwhController.text.trim().isEmpty) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        animType: AnimType.scale,
        title: 'กรุณากรอกข้อมูล',
        desc: 'กรุณากรอก kWh',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userCode = prefs.getInt('user_code') ?? 0;
    if (userCode == 0) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.scale,
        title: 'ไม่พบข้อมูล',
        desc: 'ไม่พบรหัสครัวเรือน',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    final kwh = _kwhController.text.trim();

    print(userCode);

    setState(() => _submitting = true);
    try {
      final url = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/addMonthlyEnergy',
      );

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'User_Code': userCode.toString(),
          'kwh': kwh,
        },
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        // ปิด AlertDialog ป้อนข้อมูล (ตัว dialog เดิม)
        Navigator.of(context, rootNavigator: true).pop();

        // แจ้งเตือนสำเร็จด้วย AwesomeDialog
        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.scale,
          title: 'สำเร็จ',
          desc: 'บันทึกพลังงานรายเดือนสำเร็จ',
          btnOkOnPress: () async {
            // ถ้าต้องรีเฟรชข้อมูลหน้าหลัก ให้เรียกฟังก์ชันที่เกี่ยวข้อง
            // await fetchHomeItems();
          },
        ).show();
      } else {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.scale,
          title: 'บันทึกไม่สำเร็จ',
          desc: res.body.isNotEmpty ? res.body : 'เกิดข้อผิดพลาดจากเซิร์ฟเวอร์',
          btnOkOnPress: () {},
        ).show();
      }
    } catch (e) {
      if (!mounted) return;
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.scale,
        title: 'ข้อผิดพลาดเครือข่าย',
        desc: '$e',
        btnOkOnPress: () {},
      ).show();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('เครื่องใช้ไฟฟ้า',
            style: TextStyle(color: Colors.black)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => _goToHistory('E'),
              icon:
                  const Icon(Icons.history, size: 18, color: Color(0xFF3D8361)),
              label: const Text('ประวัติ',
                  style: TextStyle(color: Color(0xFF3D8361))),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFDCF2E6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(0, 50),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
        flexibleSpace: _fabOpen
            ? GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleFab,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  color: Colors.black.withOpacity(0.5),
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          // เนื้อหาเดิมของคุณ (คงโครงสร้างเดิมไว้ทั้งหมด)
          Positioned.fill(
            child: homeItems.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: homeItems.length,
                      itemBuilder: (context, index) {
                        final item = homeItems[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AddCo2Page(item: item, useType: 'E'),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // เนื้อหาเดิมของการ์ด
                                if (item['img'] != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      children: [
                                        Align(
                                          alignment: Alignment.topCenter,
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: SizedBox(
                                              height: 100,
                                              child: Image.network(
                                                item['img'],
                                                fit: BoxFit
                                                    .cover, // จะครอบเต็มกรอบสูง 100 ถ้ากว้างไม่พอจะครอป
                                              ),
                                            ),
                                          ),
                                        ),

                                        // ปุ่มเมนูมุมขวาบน ทับบนรูป
                                        Positioned(
                                          top: -6,
                                          right: -14,
                                          child: PopupMenuButton<String>(
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20)),
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _openEditElectricDialog(
                                                    item); // modal โหมดแก้ไข
                                              } else if (value == 'delete') {
                                                _deleteHomeItem(item);
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Center(
                                                  child: Text(
                                                    'แก้ไข',
                                                    style: TextStyle(
                                                      color: Colors.amber[700],
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Center(
                                                  child: Text(
                                                    'ลบ',
                                                    style: TextStyle(
                                                      color: Colors.redAccent,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                            icon: const Icon(Icons.more_vert,
                                                color: Color.fromARGB(
                                                    255, 163, 163, 163)),
                                            // พื้นหลังกลมโปร่งแสงให้ดูชัดบนรูป
                                            offset: const Offset(0, 8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  // กรณีไม่มีรูป: ทำพื้นที่สูง 100 พร้อมเมนูมุมขวาบนเหมือนกัน
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      children: [
                                        Container(
                                            height: 100, color: Colors.black12),
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: PopupMenuButton<String>(
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20)),
                                            onSelected: (value) {
                                              if (value == 'edit')
                                                _openEditElectricDialog(item);
                                              else if (value == 'delete')
                                                _deleteHomeItem(item);
                                            },
                                            itemBuilder: (context) => [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Center(
                                                  child: Text(
                                                    'แก้ไข',
                                                    style: TextStyle(
                                                      color: Colors.amber[700],
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Center(
                                                  child: Text(
                                                    'ลบ',
                                                    style: TextStyle(
                                                      color: Colors.redAccent,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                            icon: const Icon(Icons.more_vert,
                                                color: Colors.grey),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  item['Item_type_Name'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                Text(item['location_name'] ?? '',
                                    textAlign: TextAlign.center),
                                Text('${item['size']} ${item['Unit_Name']}',
                                    textAlign: TextAlign.center),
                                Text('ใช้งาน',
                                    style: TextStyle(color: primaryColor),
                                    textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'เพิ่มเครื่องใช้ไฟฟ้า',
                          style: TextStyle(
                            fontSize: 36,
                            color: primaryColor.withOpacity(0.4),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Icon(
                          Icons.emoji_people,
                          size: 200,
                          color: primaryColor.withOpacity(0.4),
                        ),
                      ],
                    ),
                  ),
          ),

          // ชั้นพื้นหลังเทา (แสดงเมื่อ _fabOpen = true)
          if (_fabOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleFab, // แตะพื้นหลังก็ปิดเมนู
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // เมนูที่โผล่มาเมื่อ _fabOpen = true
          if (_fabOpen) ...[
            // รายเดือน (แสดงก่อน/หลังแล้วแต่ลำดับที่ต้องการ)
            AnimatedOpacity(
              opacity: _fabOpen ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: _actionRow(
                label: 'รายเดือน',
                icon: Icons.bolt,
                labelStyle: const TextStyle(fontSize: 10, color: Colors.white),
                onTap: () {
                  _toggleFab();
                  _openMonthlyEnergyDialog();
                },
              ),
            ),
            const SizedBox(height: 20),
            AnimatedOpacity(
              opacity: _fabOpen ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: _actionRow(
                label: 'เครื่องใช้ไฟฟ้า',
                labelStyle: const TextStyle(fontSize: 10, color: Colors.white),
                icon: Icons.electrical_services,
                onTap: () {
                  _toggleFab();
                  _openAddElectricDialog();
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ปุ่มล่าง: toggle (+ ↔ ×)
          FloatingActionButton(
            backgroundColor: Colors.white,
            child: Icon(_fabOpen ? Icons.close : Icons.add,
                color: _fabOpen ? Colors.redAccent : primaryColor),
            onPressed: _toggleFab,
          ),
        ],
      ),
    );
  }
}
