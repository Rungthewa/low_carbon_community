import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class AddCo2Page extends StatefulWidget {
  final Map<String, dynamic> item;
  final String useType;

  const AddCo2Page({Key? key, required this.item, required this.useType})
      : super(key: key);

  @override
  _AddCo2PageState createState() => _AddCo2PageState();
}

class _AddCo2PageState extends State<AddCo2Page> {
  final Color primaryColor = const Color(0xFF6FB188);

  // เดิมใช้ hourController เสมอ — ตอนนี้ใช้เฉพาะ useType == 'V'
  final TextEditingController hourController = TextEditingController();

  DateTime? selectedDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  bool _alwaysOn = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th_TH');
    selectedDate = DateTime.now();
    final now = TimeOfDay.now();
    startTime = now;
    endTime = now;
    if (widget.useType == 'E') {
      final s = widget.item['Use_status'];
      _alwaysOn = (s is num ? s.toInt() : int.tryParse('$s') ?? 0) == 1;
    }
  }

  // ---------- helpers ----------
  Widget _miniLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
        ),
      );

  String _fmtDate(DateTime d) => DateFormat('dd/MM/yyyy', 'th_TH').format(d);
  String _fmtApi(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

// สำหรับโชว์ใน UI
  String _fmtUi(DateTime d) => DateFormat('dd/MM/yyyy', 'th_TH').format(d);

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  double _calcDurationHours(DateTime date, TimeOfDay start, TimeOfDay end) {
    final s =
        DateTime(date.year, date.month, date.day, start.hour, start.minute);
    DateTime e =
        DateTime(date.year, date.month, date.day, end.hour, end.minute);
    if (e.isBefore(s)) e = e.add(const Duration(days: 1)); // ข้ามเที่ยงคืน
    final mins = e.difference(s).inMinutes;
    return mins / 60.0;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> _pickStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: startTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => startTime = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: endTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => endTime = picked);
  }

  Future<void> _confirmToggleAlwaysOn(bool next) async {
    AwesomeDialog(
      context: context,
      dialogType: next ? DialogType.question : DialogType.infoReverse,
      title: next ? 'ยืนยันเปิดตลอด' : 'ยืนยันปิดโหมดเปิดตลอด',
      desc: next
          ? 'ต้องการเปลี่ยนสถานะเป็น “เปิดตลอด” ใช่ไหม?\nเมื่อเปิดแล้วจะซ่อนช่องเลือกวันเวลาและปุ่มเพิ่ม'
          : 'กลับสู่โหมดปกติ จะแสดงช่องเลือกวันเวลาและปุ่มเพิ่มอีกครั้ง',
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        // ค่าเดิมจาก item ที่ได้มากับหน้า
        final old = (() {
          final v = widget.item['Use_status'];
          if (v is num) return v.toInt();
          return int.tryParse('$v') ?? 0;
        })();

        try {
          final nextNum = next ? 1 : 0; // ค่าที่ต้องการตั้ง
          final oldNum = old; // ค่าปัจจุบันที่ได้มาจาก widget.item

          final res = await http.post(
            Uri.parse(
                'https://student.crru.ac.th/651463011/LowCarbonAPI/api/updateItemStatus'),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: {
              'item_Code':
                  (widget.item['item_Code'] ?? widget.item['Item_Code'])
                      .toString(),

              // ✅ ส่ง "status" เป็นค่าที่จะตั้ง (สำคัญ)
              'status': nextNum.toString(),

              // (ตัวเลือก) ส่งคู่ไปด้วยก็ได้ เพื่อความเข้ากันได้
              'Use_status': (widget.item['Use_status'] ?? 0).toString(),
              'startStatus': oldNum.toString(),
            },
          );

          if (res.statusCode == 200) {
            // อัปเดตสถานะในหน้า และอัปเดตค่าใน item ให้สอดคล้องกับผลที่คาดว่าจะ flip
            setState(() {
              _alwaysOn = next;
              widget.item['Use_status'] = next ? 1 : 0;
            });
          } else {
            // rollback ถ้าอัปเดตล้มเหลว
            AwesomeDialog(
              context: context,
              dialogType: DialogType.error,
              title: 'อัปเดตสถานะไม่สำเร็จ',
              desc: res.body.isNotEmpty ? res.body : 'Server error',
              btnOkOnPress: () {},
            ).show();
          }
        } catch (e) {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.error,
            title: 'อัปเดตสถานะไม่สำเร็จ',
            desc: '$e',
            btnOkOnPress: () {},
          ).show();
        }
      },
    ).show();
  }

  Future<void> submitEmissionData({
    required BuildContext context,
    required int itemId,
    required DateTime? date,
    required TimeOfDay? start,
    required TimeOfDay? end,
    required String useType,
    String? distanceKm, // ใช้เมื่อเป็น V
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userCode = prefs.getInt('user_code');

    if (userCode == null) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        title: 'ไม่พบรหัสผู้ใช้งาน',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    if (date == null) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        title: 'กรุณาเลือกวันที่',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    // V = เดินทาง -> ต้องกรอกระยะทาง
    if (useType == 'V') {
      if (distanceKm == null || distanceKm.trim().isEmpty) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.warning,
          title: 'กรุณากรอกระยะทาง (กม.)',
          btnOkOnPress: () {},
        ).show();
        return;
      }
    } else {
      // E/F = ต้องมี start/end
      if (start == null || end == null) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.warning,
          title: 'กรุณาเลือกเวลาเริ่มและสิ้นสุด',
          btnOkOnPress: () {},
        ).show();
        return;
      }
    }

    Future<void> _updateAlwaysOnServer({required bool next}) async {
      // TODO: แก้ให้ตรงกับ API ของคุณ
      final url = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/updateItemStatus',
      );
      try {
        final res = await http.post(
          url,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'item_Code': (widget.item['item_Code'] ?? widget.item['Item_Code'])
                .toString(),
            'status': next ? '1' : '0',
          },
        );
        if (res.statusCode != 200) {
          throw Exception(res.body);
        }
      } catch (e) {
        // ถ้าอัปเดตล้มเหลว ให้รีเวิร์สค่าในหน้าจอกลับ
        setState(() => _alwaysOn = !next);
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'อัปเดตสถานะไม่สำเร็จ',
          desc: '$e',
          btnOkOnPress: () {},
        ).show();
      }
    }

    final dateStr = _fmtApi(date);
    String? startStr, endStr, hourStr;

    if (useType != 'V') {
      final hours = _calcDurationHours(date, start!, end!);
      startStr = _fmtTime(start);
      endStr = _fmtTime(end);
      hourStr = hours.toStringAsFixed(2); // เผื่อหลังบ้านยังต้องการ hour
    }

    final url = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/addEmission');

    // ส่งช่วงเวลา + hour (E/F) หรือส่งระยะทาง (V)
    final body = <String, String>{
      'User_Code': userCode.toString(),
      'item': itemId.toString(),
      'date': _fmtApi(date),
      'useType': useType,
      if (useType != 'V') ...{
        'start_time': startStr!,
        'end_time': endStr!,
        'hour': hourStr!, // เผื่อ compat
      } else ...{
        'distance': distanceKm!, // เดินทางใช้ distance
      },
    };

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
        final data = json.decode(response.body);
        final co2 = data['CO2_emission'];

        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.scale,
          title: 'บันทึกสำเร็จ',
          desc: 'คุณได้ปล่อยก๊าซ CO₂ ประมาณ $co2 kgCO₂e',
          btnOkOnPress: () => Navigator.pop(context),
        ).show();
      } else {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'ผิดพลาด',
          desc: 'เกิดข้อผิดพลาด: ${response.body}',
          btnOkOnPress: () {},
        ).show();
      }
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        title: 'ข้อผิดพลาดเครือข่าย',
        desc: '$e',
        btnOkOnPress: () {},
      ).show();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    // คิดชั่วโมงเพื่อแสดง (E/F เท่านั้น)
    final hoursText =
        (selectedDate != null && startTime != null && endTime != null)
            ? _calcDurationHours(selectedDate!, startTime!, endTime!)
                .toStringAsFixed(2)
            : '--';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Text(
                widget.useType == 'E'
                    ? 'ใช้งานเครื่องใช้ไฟฟ้า'
                    : widget.useType == 'V'
                        ? 'เดินทางโดยใช้เชื้อเพลิง'
                        : 'ทำอาหาร',
                style: TextStyle(
                  fontSize: 18,
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              // วันที่
              Align(
                  alignment: Alignment.centerLeft,
                  child: _miniLabel('วันที่เริ่มใช้งาน')),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    selectedDate != null
                        ? _fmtUi(selectedDate!)
                        : 'เลือกวันที่เริ่มใช้',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // เวลา (สองช่อง) — คงสไตล์เดิม
              if (widget.useType != 'V') ...[
                Row(
                  children: [
                    // เวลาเริ่มต้น
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _miniLabel('เวลาเริ่มต้น'),
                          GestureDetector(
                            onTap: _pickStart,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                startTime != null
                                    ? _fmtTime(startTime!)
                                    : 'เลือกเวลาเริ่มต้น',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // เวลาสิ้นสุด
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _miniLabel('เวลาสิ้นสุด'),
                          GestureDetector(
                            onTap: _pickEnd,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                endTime != null
                                    ? _fmtTime(endTime!)
                                    : 'เลือกเวลาสิ้นสุด',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              ],

              const SizedBox(height: 12),

              // การ์ดรายละเอียด (คงเดิม)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    widget.useType == 'E' || widget.useType == 'F'
                        ? item['img'] != null
                            ? Image.network(item['img'], height: 120)
                            : Image.asset('images/default.png', height: 120)
                        : item['type'] == 'C'
                            ? Image.asset('images/car.png', height: 120)
                            : Image.asset('images/motorcye.png', height: 120),
                    const SizedBox(height: 8),
                    Text(
                      widget.useType == 'E'
                          ? '${item['Item_type_Name'] ?? ''}\n${item['size']} ${item['Unit_Name']}\n${item['location_name']}'
                          : item['fuel_Name'] ?? '',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // ถ้าเดินทาง ให้กรอกระยะทางเหมือนเดิม
                    if (widget.useType == 'V')
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('ระยะทางที่ใช้ (กิโลเมตร)',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: TextField(
                              controller: hourController,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '0',
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                    // ถ้าไม่ใช่เดินทาง แสดงเวลารวม (อ่านอย่างเดียว)
                    if (widget.useType != 'V' && !_alwaysOn)
                      Row(
                        children: [
                          const Expanded(
                            child: Text('เวลารวม (ชั่วโมง)',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Container(
                            width: 110,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.black26),
                              color: Colors.white,
                            ),
                            child: Text(hoursText),
                          ),
                        ],
                      ),

                    const SizedBox(height: 16),
                    if (widget.useType == 'E')
                      Row(
                        children: [
                          Text('เปิดตลอด',
                              style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 10),
                          Switch.adaptive(
                            value: _alwaysOn,
                            activeColor: Colors.white,
                            activeTrackColor: primaryColor,
                            onChanged: (val) => _confirmToggleAlwaysOn(
                                val), // <- เรียกเมธอดที่เพิ่ม
                          ),
                        ],
                      ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'กรอก/เลือกช่วงเวลาใช้งานของคุณเพื่อให้ระบบ\nเก็บข้อมูลการปล่อยก๊าซเรือนกระจกของคุณ',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // ปุ่มเพิ่ม — ซ่อนเมื่อเครื่องใช้ไฟฟ้าและเปิดตลอด
              if (!(widget.useType == 'E' && _alwaysOn))
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final itemId = widget.item['item_Code'];
                      if (widget.useType == 'V') {
                        submitEmissionData(
                          context: context,
                          itemId: itemId,
                          date: selectedDate,
                          start: null,
                          end: null,
                          useType: widget.useType,
                          distanceKm: hourController.text.trim(),
                        );
                      } else {
                        submitEmissionData(
                          context: context,
                          itemId: itemId,
                          date: selectedDate,
                          start: startTime,
                          end: endTime,
                          useType: widget.useType,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('เพิ่ม', style: TextStyle(fontSize: 18)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
