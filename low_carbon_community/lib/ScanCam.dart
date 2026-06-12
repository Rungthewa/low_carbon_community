import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'Joiner.dart'; 

class QRScannerPage extends StatelessWidget {
  const QRScannerPage({super.key});

  Future<void> handleScan(BuildContext context, String scannedValue) async {
    try {
      final activityCode = int.tryParse(scannedValue);

      if (activityCode == null) {
        throw Exception('QR Code ไม่ถูกต้อง (ค่า: $scannedValue)');
      }

      final prefs = await SharedPreferences.getInstance();
      final userCode = prefs.getInt('user_code');

      if (userCode == null) {
        throw Exception('ไม่พบ user_code ในเครื่อง');
      }

      final uri = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/updateJoinStatus',
      );

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'activity_code': activityCode,
          'user_code': userCode,
        }),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['status'] == true) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.scale,
          title: 'สำเร็จ',
          desc: 'ยืนยันการเข้าร่วมกิจกรรมสำเร็จ',
          btnOkOnPress: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const JoinActivityListPage()),
            );
          },
        ).show();
      } else {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.scale,
          title: 'ล้มเหลว',
          desc: body['message'] ?? 'ไม่สามารถอัปเดตได้',
          btnOkOnPress: () {},
        ).show();
      }
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.scale,
        title: 'ข้อผิดพลาด',
        desc: e.toString(),
        btnOkOnPress: () {},
      ).show();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("แสกน QR Code"),
        backgroundColor: const Color(0xFF6FB188),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.noDuplicates,
              formats: [BarcodeFormat.qrCode],
            ),
            onDetect: (barcodeCapture) {
              for (final barcode in barcodeCapture.barcodes) {
                final value = barcode.rawValue;
                if (value != null) {
                  handleScan(context, value);
                  break;
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 4),
                borderRadius: BorderRadius.circular(20),
                color: Colors.transparent,
              ),
              child: const Center(
                child: Icon(Icons.qr_code_scanner, color: Colors.white, size: 40),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
