import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/services.dart';

class AddVehicleModal extends StatefulWidget {
  final List<Map<String, dynamic>> itemTypes; // รายการเชื้อเพลิง (fuel)
  final int? selectedItem; // fuel_Code ที่เลือกไว้
  final TextEditingController sizeController; // ไม่ได้ใช้แล้ว (เดิม)
  final TextEditingController quantityController; // ใช้เป็น "ทะเบียนรถ"
  final ValueChanged<int?> onItemChanged;
  final VoidCallback onSubmitted;

  // โหมดแก้ไข
  final bool isEdit; // default: false
  final dynamic editingItemCode; // item_Code ที่จะแก้ไข
  final String? initialRadio; // 'C'/'M'
  final String? initialEff; // ✅ เพิ่ม: ค่าเริ่มต้น กม./ลิตร

  const AddVehicleModal({
    required this.itemTypes,
    required this.selectedItem,
    required this.sizeController,
    required this.quantityController,
    required this.onItemChanged,
    required this.onSubmitted,
    this.isEdit = false,
    this.editingItemCode,
    this.initialRadio,
    this.initialEff,
  });

  @override
  State<AddVehicleModal> createState() => _AddVehicleModalState();
}

class _AddVehicleModalState extends State<AddVehicleModal> {
  int? localSelectedItem;
  final Color primaryColor = const Color(0xFF6FB188);

  /// 'C' = รถยนต์, 'M' = มอเตอร์ไซค์
  String radioValue = 'C';

  /// อัตราการสิ้นเปลือง (กม./ลิตร)
  final TextEditingController _effController = TextEditingController();

  @override
  @override
  @override
  void initState() {
    super.initState();

    int? sent = widget.selectedItem;
    // ถ้าส่งมาเป็นสตริงก็แปลง
    if (sent == null && widget.selectedItem != null) {
      sent = int.tryParse(widget.selectedItem.toString());
    }

    final has = widget.itemTypes.any((it) {
      final code = _asInt(it['fuel_Code']);
      return code == sent;
    });

    localSelectedItem =
        has ? sent : null; // ✅ ถ้าไม่เจอ ปล่อย null ให้โชว์ hint

    radioValue = (widget.initialRadio ?? "C").toString();
    if (widget.initialEff != null) _effController.text = widget.initialEff!;
  }

  @override
  void dispose() {
    _effController.dispose();
    super.dispose();
  }

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  int? _ensureValueInItems(int? value, List<Map<String, dynamic>> items) {
    if (value == null) return null;
    final has = items.any((it) => _asInt(it['fuel_Code']) == value);
    return has ? value : null; // ถ้าไม่มีในรายการ ให้เป็น null เพื่อโชว์ hint
  }

  Future<void> submitVehicleItem() async {
    final prefs = await SharedPreferences.getInstance();
    final homeCode = prefs.getInt('home_Code') ?? 0;

    final itemType = localSelectedItem; // fuel_Code
    final plate = widget.quantityController.text.trim();
    final effText = _effController.text.trim();
    final eff = double.tryParse(effText);

    if (itemType == null || plate.isEmpty || eff == null || eff <= 0) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        title: "ข้อมูลไม่ครบ",
        desc:
            "กรุณาเลือกเชื้อเพลิง, กรอกทะเบียนรถ และอัตราการสิ้นเปลืองให้ถูกต้อง",
        btnOkOnPress: () {},
      ).show();
      return;
    }

    // สร้าง payload
    final body = <String, String>{
      'home_Code': homeCode.toString(),
      'fuel_Code': itemType.toString(),
      'type': radioValue, // 'C' หรือ 'M'
      'vehicle_type': radioValue, // เผื่อหลังบ้านรับอีกชื่อ
      'plate_no': plate,
      'km_per_litre': eff.toString(),
    };

    // โหมดแก้ไข -> ส่ง item_Code และเรียก updateVehicle
    if (widget.isEdit && widget.editingItemCode != null) {
      body['item_Code'] = widget.editingItemCode.toString();
    }

    final url = Uri.parse(
      widget.isEdit
          ? 'https://student.crru.ac.th/651463011/LowCarbonAPI/api/updateVehicle'
          : 'https://student.crru.ac.th/651463011/LowCarbonAPI/api/addVehicle',
    );

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
        // หยิบ context ของ rootNavigator มาก่อน (จะไม่หลุดแม้ modal แม่ถูก pop)
        final rootCtx = Navigator.of(context, rootNavigator: true).context;

        AwesomeDialog(
          context: rootCtx,
          dialogType: DialogType.success,
          title: "สำเร็จ",
          desc: widget.isEdit
              ? "บันทึกการแก้ไขเรียบร้อย"
              : "บันทึกยานพาหนะเรียบร้อย",
          // อย่ากำหนด autoDismiss เลย (ปล่อยให้เป็น true)
          btnOkOnPress: () {}, // ให้มันปิดเอง
          onDismissCallback: (type) {
            // ถูกเรียกหลัง dialog ปิดแล้ว -> ค่อยทำงานต่อ เช่น refresh/ปิด modal แม่
            widget.onSubmitted(); // ถ้าในนี้มี Navigator.pop ก็จะปลอดภัย
          },
        ).show();
      } else {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: "ผิดพลาด",
          desc: "รหัส ${response.statusCode}\n${response.body}",
          btnOkOnPress: () {},
        ).show();
      }
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        title: "ข้อผิดพลาดเครือข่าย",
        desc: e.toString(),
        btnOkOnPress: () {},
      ).show();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.70,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_car_filled,
                  size: 60, color: Colors.black54),
              const SizedBox(height: 8),
              Text(
                'ยานพาหนะ',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF3D8361),
                ),
              ),
              const SizedBox(height: 16),

              // ชนิดยานพาหนะ (Radio)
              Align(
                alignment: Alignment.centerLeft,
                child: Text('ชนิดยานพาหนะ',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: primaryColor)),
              ),
              const SizedBox(height: 6),
              _vehicleTypeRadios(),

              const SizedBox(height: 6),

              // เชื้อเพลิง (Dropdown) — ปิดเมื่อแก้ไข เหมือนหน้าไฟฟ้า
              Align(
                alignment: Alignment.centerLeft,
                child: Text('เชื้อเพลิง',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: primaryColor)),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                height: 56,
                decoration: BoxDecoration(
                  color: widget.isEdit
                      ? Colors.grey[400]
                      : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: DropdownButton<int>(
                  isExpanded: true,
                  value:
                      localSelectedItem, // ✅ จะเป็น int ที่มีใน items หรือ null
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: widget.isEdit ? Colors.grey.shade700 : Colors.black,
                  ),
                  underline: const SizedBox(),
                  hint: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('เลือกเชื้อเพลิง',
                        style: TextStyle(color: Colors.grey[700])),
                  ),
                  // ✅ เวลา disabled ให้โชว์ชื่อ fuel ตาม localSelectedItem
                  disabledHint: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      () {
                        if (localSelectedItem == null) return 'เลือกเชื้อเพลิง';
                        final m = widget.itemTypes.firstWhere(
                          (it) => _asInt(it['fuel_Code']) == localSelectedItem,
                          orElse: () => const {},
                        );
                        return (m['fuel_Name'] ?? 'เลือกเชื้อเพลิง').toString();
                      }(),
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                  onChanged: widget.isEdit
                      ? null
                      : (value) {
                          setState(() => localSelectedItem = value);
                          widget.onItemChanged(value);
                        },
                  items: widget.itemTypes.map((it) {
                    final code = _asInt(it['fuel_Code']) ?? 0;
                    return DropdownMenuItem<int>(
                      value: code,
                      child: Text((it['fuel_Name'] ?? '').toString()),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              _buildTextField(
                controller: _effController,
                label: 'อัตราการสิ้นเปลือง (กม./ลิตร)',
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'กรุณากรอกอัตราการสิ้นเปลือง'
                    : null,
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: widget.quantityController,
                label: 'ทะเบียนรถ',
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'กรุณากรอกทะเบียนรถ'
                    : null,
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: submitVehicleItem,
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
                      onPressed: () => Navigator.pop(context),
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

  // ===== Helper UI =====
  Widget _vehicleTypeRadios() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Radio<String>(
                    value: 'C', // รถยนต์
                    groupValue: radioValue,
                    activeColor: primaryColor,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (value) => setState(() => radioValue = value!),
                  ),
                  Text('รถยนต์', style: TextStyle(color: primaryColor)),
                ],
              ),
              Row(
                children: [
                  Radio<String>(
                    value: 'M', // มอเตอร์ไซค์
                    groupValue: radioValue,
                    activeColor: primaryColor,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (value) => setState(() => radioValue = value!),
                  ),
                  Text('มอเตอร์ไซค์', style: TextStyle(color: primaryColor)),
                ],
              ),
            ],
          ),
        ],
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
