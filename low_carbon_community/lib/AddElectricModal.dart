import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class AddElectricModal extends StatefulWidget {
  final List<Map<String, dynamic>> itemTypes;
  final int? selectedItem;
  final bool isEdit; // โหมดแก้ไขหรือไม่ (ค่าเริ่ม false)
  final dynamic editingItemCode; // item_Code ที่จะแก้ไข
  final String? initialRadio;
  // final TextEditingController wattController;
  final TextEditingController sizeController;
  final TextEditingController locationController;
  final ValueChanged<int?> onItemChanged;
  final VoidCallback onSubmitted;

  const AddElectricModal({
    required this.itemTypes,
    required this.selectedItem,
    // required this.wattController,
    required this.sizeController,
    required this.locationController,
    required this.onItemChanged,
    required this.onSubmitted,
    this.isEdit = false,
    this.editingItemCode,
    this.initialRadio,
  });

  @override
  State<AddElectricModal> createState() => _AddElectricModalState();
}

class _AddElectricModalState extends State<AddElectricModal> {
  int? localSelectedItem;
  final Color primaryColor = Color(0xFF6FB188);

  String radioValue = "Normal";

  @override
  void initState() {
    super.initState();
    localSelectedItem = widget.selectedItem;
    radioValue = (widget.initialRadio ?? "N").toString();
  }

  String getUnitName(int? selectedCode) {
    final found = widget.itemTypes.firstWhere(
      (item) => item['Item_type_Code'] == selectedCode,
      orElse: () => {'Unit_Name': ''},
    );
    return found['Unit_Name'] ?? '';
  }

  int getManyType(int? selectedCode) {
    final found = widget.itemTypes.firstWhere(
      (item) => item['Item_type_Code'] == selectedCode,
      orElse: () => {'Many_Type': 1},
    );
    return found['Many_Type'] ?? 1;
  }

  Future<void> submitElectricItem() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final homeCode = prefs.getInt('home_Code') ?? 0;
    final itemType = localSelectedItem;
    final size = widget.sizeController.text;
    final location = widget.locationController.text;
    final typeName = radioValue; // 'N'/'I'

    if (itemType == null || location.isEmpty) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        title: "กรอกไม่ครบ",
        desc: "กรุณากรอกข้อมูลให้ครบถ้วน",
        btnOkOnPress: () {},
      ).show();
      return;
    }

    final body = <String, String>{
      'Item_type_Code': itemType.toString(),
      'size': size,
      'location': location,
      'type': typeName,
      'home_Code': homeCode.toString(),
    };

    // ⬇️ ถ้าแก้ไข ต้องส่ง item_Code ให้หลังบ้าน
    if (widget.isEdit && widget.editingItemCode != null) {
      body['item_Code'] = widget.editingItemCode.toString();
    }

    // ⬇️ เลือก endpoint ตามโหมด
    final url = Uri.parse(
      widget.isEdit
          ? 'https://student.crru.ac.th/651463011/LowCarbonAPI/api/updateItem'
          : 'https://student.crru.ac.th/651463011/LowCarbonAPI/api/addItem',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      // debug
      // print('StatusCode: ${response.statusCode}');
      // print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        widget.onSubmitted();
        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.bottomSlide,
          title: "สำเร็จ",
          desc: widget.isEdit ? "บันทึกการแก้ไขสำเร็จ" : "บันทึกข้อมูลสำเร็จ",
          btnOkOnPress: () {
            Navigator.of(context, rootNavigator: true).pop(); // ปิด modal
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
    int manyType = getManyType(localSelectedItem);

    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.55,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.electrical_services,
                  size: 60, color: Colors.black54),
              const SizedBox(height: 8),
              Text(
                'เครื่องใช้ไฟฟ้า',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3D8361),
                ),
              ),
              const SizedBox(height: 16),

              // Dropdown
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12),
                height: 60,
                decoration: BoxDecoration(
                  color: (widget.isEdit ?? false)
                      ? Colors.grey[400]
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.grey.shade300, // สีกรอบเทา
                    width: 1.0, // ความหนากรอบ
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: localSelectedItem,
                  // เปลี่ยนสีไอคอนตามสถานะ enabled/disabled
                  icon: Padding(
                    padding: const EdgeInsets.only(
                        top: 8.0), // ปรับค่า top ตามต้องการ
                    child: Icon(
                      Icons.arrow_drop_down,
                      color: (widget.isEdit ?? false)
                          ? Colors.grey.shade700
                          : Colors.black,
                    ),
                  ),
                  underline: SizedBox.shrink(),
                  hint: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '-- เลือก --',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                  // เมื่อ disabled ให้แสดง disabledHint (สีเทาเข้ม)
                  disabledHint: localSelectedItem != null
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.itemTypes
                                    .firstWhere(
                                      (it) =>
                                          it['Item_type_Code'] ==
                                          localSelectedItem,
                                      orElse: () => {'Item_type_Name': ''},
                                    )['Item_type_Name']
                                    ?.toString() ??
                                '',
                            style: TextStyle(
                                color: Colors.grey.shade700, fontSize: 14),
                          ),
                        )
                      : null,

                  // ถ้าเป็น edit จะ disable (onChanged = null)
                  onChanged: (widget.isEdit ?? false)
                      ? null
                      : (value) {
                          setState(() {
                            localSelectedItem = value;
                            radioValue = "N"; // reset radio on change
                          });
                          widget.onItemChanged(value);
                        },

                  selectedItemBuilder: (BuildContext context) {
                    return widget.itemTypes.map<Widget>((item) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            (item['Item_type_Name'] ?? '').toString(),
                            style: TextStyle(
                              color: (widget.isEdit ?? false)
                                  ? Colors.grey.shade700
                                  : Colors.black,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      );
                    }).toList();
                  },

                  // รายการในเมนู (เวลาเปิด dropdown)
                  items: widget.itemTypes.map((item) {
                    return DropdownMenuItem<int>(
                      value: item['Item_type_Code'] as int?,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item['Item_type_Name'] ?? '',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),
              // _buildTextField(widget.wattController, 'กำลังไฟฟ้า (วัตต์)'),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: widget.sizeController,
                      label: 'ความจุ / ขนาด / วัตต์',
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'กรุณากรอกค่าความจุ'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    getUnitName(localSelectedItem), // ✅ Dynamic unit name
                    style: TextStyle(fontSize: 16, color: primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // ✅ RadioBox เงื่อนไข Many_Type
              if (manyType == 2 || manyType == 1)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Radio<String>(
                              value: "N",
                              groupValue: radioValue,
                              activeColor: primaryColor,
                              onChanged: (value) {
                                setState(() => radioValue = value!);
                              },
                            ),
                            Text(
                              "ปกติ",
                              style: TextStyle(color: primaryColor),
                            ),
                          ],
                        ),
                        if (manyType == 2)
                          Row(
                            children: [
                              Radio<String>(
                                value: "I",
                                groupValue: radioValue,
                                activeColor: primaryColor,
                                onChanged: (value) {
                                  setState(() => radioValue = value!);
                                },
                              ),
                              Text(
                                "อินเวอร์เตอร์",
                                style: TextStyle(color: primaryColor),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),

              _buildTextField(
                controller: widget.locationController,
                label: 'ที่ตั้งของเครื่อง',
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'กรุณากรอกค่าที่ตั้งของเครื่อง'
                    : null,
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: // เก็บค่าตัวเลือกไว้ใช้
                          submitElectricItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: StadiumBorder(),
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
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: StadiumBorder(),
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
