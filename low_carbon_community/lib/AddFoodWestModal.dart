import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddFoodWasteModal extends StatefulWidget {
  final VoidCallback onSubmitted;

  const AddFoodWasteModal({Key? key, required this.onSubmitted})
      : super(key: key);

  @override
  _AddFoodWasteModalState createState() => _AddFoodWasteModalState();
}

class _AddFoodWasteModalState extends State<AddFoodWasteModal> {
  final TextEditingController wasteController = TextEditingController();
  final Color primaryColor = Color(0xFF6FB188);

  Future<void> _submitFoodWaste() async {
    final prefs = await SharedPreferences.getInstance();
    final userCode = prefs.getInt('user_code') ?? 0;
    final token = prefs.getString('auth_token') ?? '';
    final weight = double.tryParse(wasteController.text.trim()) ?? 0;

    if (weight <= 0) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        title: 'กรอกน้ำหนักไม่ถูกต้อง',
        desc: 'โปรดระบุน้ำหนักเศษอาหารมากกว่า 0',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    final url = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/addFoodWaste');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'User_Code': userCode,
        'weight': weight,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final co2 = ((data['CO2_emission'] is num)
        ? (data['CO2_emission'] as num).toDouble()
        : double.tryParse('${data['CO2_emission']}') ?? 0.0)
    .toStringAsFixed(2);
      Navigator.of(context).pop();
      widget.onSubmitted();
      AwesomeDialog(
        context: context,
        dialogType: DialogType.success,
        title: 'สำเร็จ',
        desc: 'คุณได้ปล่อยก๊าซ CO₂ ประมาณ $co2 kg',
        btnOkOnPress: () => Navigator.pop(context),
      ).show();
    } else {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        title: 'ผิดพลาด',
        desc: 'ไม่สามารถบันทึกข้อมูลได้',
        btnOkOnPress: () {},
      ).show();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.restaurant_rounded, size: 48, color: Colors.grey),
        const SizedBox(height: 8),
        const Text(
          'น้ำหนักเศษอาหาร (กิโลกรัม)',
          style: TextStyle(fontSize: 18, color: Color(0xFF4D8D5B)),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(24),
          ),
          child: TextField(
            controller: wasteController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'เช่น 0.3',
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _submitFoodWaste,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            shape: StadiumBorder(),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text('เพิ่ม', style: TextStyle(color: Colors.white)),
          ),
        ),
        const SizedBox(height: 5),
        IconButton(
          icon: const Icon(Icons.cancel, size: 50, color: Colors.redAccent),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
