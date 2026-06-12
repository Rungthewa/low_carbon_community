import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/services.dart';

class AddFoodFuelModal extends StatefulWidget {
  final List<Map<String, dynamic>> itemTypes;
  final int? selectedItem;
  final ValueChanged<int?> onItemChanged;
  final VoidCallback onSubmitted;

  final bool isEdit; // โหมดแก้ไข
  final dynamic editingItemCode;
  final String? initialEff; // ตั้งค่าเริ่มต้น

  const AddFoodFuelModal({
    required this.itemTypes,
    required this.selectedItem,
    required this.onItemChanged,
    required this.onSubmitted,
    this.isEdit = false,
    this.editingItemCode,
    this.initialEff,
  });

  @override
  State<AddFoodFuelModal> createState() => _AddFoodFuelModalState();
}

class _AddFoodFuelModalState extends State<AddFoodFuelModal> {
  int? localSelectedItem;
  final Color primaryColor = const Color(0xFF6FB188);
  final TextEditingController _effController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final sent = widget.selectedItem;
    final has = widget.itemTypes.any(
      (m) => _asInt(m['fuel_Code'] ?? m['food_Code']) == (sent ?? -1),
    );
    localSelectedItem =
        has ? sent : null; // ถ้าไม่เจอ ให้เป็น null เพื่อแสดง hint

    if (widget.initialEff != null) _effController.text = widget.initialEff!;
  }

  int _asInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  String _fuelNameOf(int? code) {
    if (code == null) return 'เลือกเชื้อเพลิง';
    final m = widget.itemTypes.firstWhere(
      (it) => _asInt(it['fuel_Code'] ?? it['food_Code']) == code,
      orElse: () => const {},
    );
    return (m['fuel_Name'] ?? m['food_Name'] ?? 'เลือกเชื้อเพลิง').toString();
  }

  Future<void> submitFoodFuelItem() async {
    final prefs = await SharedPreferences.getInstance();
    final homeCode = prefs.getInt('home_Code') ?? 0;
    final itemType = localSelectedItem;
    final effText = _effController.text.trim();
    final eff = double.tryParse(effText);

    if (itemType == null || eff == null || eff <= 0) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        animType: AnimType.rightSlide,
        title: 'แจ้งเตือน',
        desc: 'กรุณาเลือกเชื้อเพลิงและกรอกอัตราการสิ้นเปลือง (> 0)',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    final body = <String, String>{
      'fuel_Code': itemType.toString(),
      'home_Code': homeCode.toString(),
      'km_per_litre': eff.toString(),
    };

    final url = Uri.parse(
      widget.isEdit
          ? 'https://student.crru.ac.th/651463011/LowCarbonAPI/api/updateFoodFuel'
          : 'https://student.crru.ac.th/651463011/LowCarbonAPI/api/addFoodFuel',
    );

    if (widget.isEdit && widget.editingItemCode != null) {
      body['item_Code'] = widget.editingItemCode.toString();
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        if (!mounted) return;

        // 1) ปิด AlertDialog (ฟอร์ม) ตัวที่กำลังเปิดอยู่ก่อน
        final rootNav = Navigator.of(context, rootNavigator: true);
        if (rootNav.canPop()) rootNav.pop();

        // 2) โชว์ Success บน root context (ไม่ผูกกับ dialog ที่เพิ่งปิด)
        final rootCtx = rootNav.context;
        AwesomeDialog(
          context: rootCtx,
          dialogType: DialogType.success,
          animType: AnimType.scale,
          title: 'สำเร็จ',
          desc:
              widget.isEdit ? 'บันทึกการแก้ไขเรียบร้อย' : 'บันทึกข้อมูลสำเร็จ',
          // ปล่อยให้ dialog ปิดเองเมื่อกด OK
          btnOkOnPress: () {},
          // 3) หลังปิด success แล้ว ค่อย callback (ไปรีเฟรช/อย่างอื่น)
          onDismissCallback: (type) {
            // อย่า pop ซ้ำในนี้ เพราะปิดฟอร์มไปแล้วขั้นตอนที่ 1
            widget.onSubmitted();
          },
        ).show();
      } else {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.leftSlide,
          title: 'ผิดพลาด',
          desc: 'บันทึกล้มเหลว: ${response.statusCode}\n${response.body}',
          btnOkOnPress: () {},
        ).show();
      }
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.bottomSlide,
        title: 'ข้อผิดพลาด',
        desc: 'เกิดข้อผิดพลาดเครือข่าย: $e',
        btnOkOnPress: () {},
      ).show();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.65,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department,
                  size: 60, color: Colors.deepOrange),
              const SizedBox(height: 8),
              const Text(
                'ใช้เชื้อเพลิงในการทำอาหาร',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3D8361),
                ),
              ),
              const SizedBox(height: 16),

              // Dropdown (disabled เมื่อแก้ไข)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                height: 56,
                decoration: BoxDecoration(
                  color: widget.isEdit
                      ? Colors.grey[400]
                      : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: localSelectedItem,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: widget.isEdit ? Colors.grey.shade700 : Colors.black,
                  ),
                  underline: const SizedBox(),
                  hint: Text('เลือกเชื้อเพลิง',
                      style: TextStyle(color: Colors.grey[700])),
                  disabledHint: Text(
                    _fuelNameOf(localSelectedItem),
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  onChanged: widget.isEdit
                      ? null
                      : (value) {
                          setState(() => localSelectedItem = value);
                          widget.onItemChanged(value);
                        },
                  items: widget.itemTypes.map((item) {
                    final int code =
                        _asInt(item['fuel_Code'] ?? item['food_Code']);
                    final String name =
                        (item['fuel_Name'] ?? item['food_Name'] ?? '')
                            .toString();
                    return DropdownMenuItem<int>(
                        value: code, child: Text(name));
                  }).toList(),
                ),
              ),

              const SizedBox(height: 12),

              // อัตราการสิ้นเปลือง
              _buildTextField(
                controller: _effController,
                label: 'อัตราการสิ้นเปลือง (ต่อชม.)',
                inputType: const TextInputType.numberWithOptions(decimal: true),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: submitFoodFuelItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        widget.isEdit ? 'บันทึก' : 'เพิ่ม',
                        style:
                            const TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
}
