import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportEnergyComparePage extends StatefulWidget {
  const ReportEnergyComparePage({super.key});

  @override
  State<ReportEnergyComparePage> createState() => _ReportEnergyComparePageState();
}

class _ReportEnergyComparePageState extends State<ReportEnergyComparePage> {
  final Color primaryColor = const Color(0xFF6FB188);

  int cmpYear = DateTime.now().year;
  int cmpMonth = DateTime.now().month;
  Map<String, dynamic>? cmpData;
  bool cmpLoading = false;

  DateTime _firstDayOfMonth(int y, int m) => DateTime(y, m, 1);
  DateTime _lastDayOfMonth(int y, int m) => DateTime(y, m + 1, 0);
  String _thaiMonthLabel(int y, int m) => DateFormat('LLLL yyyy', 'th_TH').format(DateTime(y, m, 1));
  String _fmtKg(num n) => n.toStringAsFixed(2);
  String _fmtApi(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th_TH');
    _loadMonthlyCompare(); // โหลดทันทีเมื่อเข้า
  }

  Future<void> _loadMonthlyCompare() async {
    setState(() => cmpLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final homeCode = prefs.getInt('home_Code') ?? 0;

      final start = _fmtApi(_firstDayOfMonth(cmpYear, cmpMonth));
      final end = _fmtApi(_lastDayOfMonth(cmpYear, cmpMonth));

      final uri = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/report/range-summary'
        '?home_Code=$homeCode&start=$start&end=$end',
      );

      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          final rows = decoded['data'];
          final meta = decoded['meta'];
          setState(() {
            cmpData = {
              'rows': (rows is List) ? rows : <dynamic>[],
              'meta': (meta is Map) ? meta : <String, dynamic>{},
            };
          });
        } else {
          setState(() => cmpData = {'rows': <dynamic>[], 'meta': <String, dynamic>{}});
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดเปรียบเทียบไม่สำเร็จ: ${res.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => cmpLoading = false);
    }
  }

  Widget _buildComparePicker() {
    final years = List<int>.generate(6, (i) => DateTime.now().year - 2 + i);
    final months = List<int>.generate(12, (i) => i + 1);

    double asDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    Widget buildTable() {
      final totals = (cmpData?['meta'] is Map && cmpData!['meta']['totals'] is Map)
          ? Map<String, dynamic>.from(cmpData!['meta']['totals'])
          : <String, dynamic>{};

      final List<Map<String, dynamic>> elecMonthly =
          (totals['ElecMonthly'] is List)
              ? List<Map<String, dynamic>>.from(
                  (totals['ElecMonthly'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
              : <Map<String, dynamic>>[];

      final sumDailyCo2 = elecMonthly.fold<double>(0.0, (s, it) => s + asDouble(it['co2']));

      final List<Map<String, dynamic>> monthlyList =
          (totals['monthly'] is List)
              ? List<Map<String, dynamic>>.from(
                  (totals['monthly'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
              : <Map<String, dynamic>>[];

      final monthlyCo2 = monthlyList.isNotEmpty
          ? monthlyList.fold<double>(0.0, (s, it) => s + asDouble(it['co2']))
          : asDouble(totals['co2']);

      final reducingTotal = asDouble(totals['reducing_total']);
      final diff = (sumDailyCo2 - monthlyCo2).abs();
      final isMatch = diff < 0.01;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 720),
          child: Table(
            columnWidths: const {0: FlexColumnWidth(1.4), 1: FlexColumnWidth(1.4), 2: FlexColumnWidth(1.4), 3: FlexColumnWidth(1.2)},
            border: TableBorder.symmetric(
              inside: const BorderSide(color: Color(0x22000000), width: 1),
              outside: const BorderSide(color: Colors.transparent, width: 0),
            ),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              const TableRow(
                decoration: BoxDecoration(color: Color(0xFFEFF3F0)),
                children: [
                  Padding(padding: EdgeInsets.all(10), child: Text('รวมประจำวัน', style: TextStyle(fontWeight: FontWeight.w700))),
                  Padding(padding: EdgeInsets.all(10), child: Text('เดือน', style: TextStyle(fontWeight: FontWeight.w700))),
                  Padding(padding: EdgeInsets.all(10), child: Text('การลดก๊าซเรือนกระจก', style: TextStyle(fontWeight: FontWeight.w700))),
                  Padding(padding: EdgeInsets.all(10), child: Text('หมายเหตุ', style: TextStyle(fontWeight: FontWeight.w700))),
                ],
              ),
              TableRow(
                children: [
                  Padding(padding: const EdgeInsets.all(10), child: Text('${_fmtKg(sumDailyCo2)} kg', softWrap: false, overflow: TextOverflow.fade)),
                  Padding(padding: const EdgeInsets.all(10), child: Text('${_fmtKg(monthlyCo2)} kg', softWrap: false, overflow: TextOverflow.fade)),
                  Padding(padding: const EdgeInsets.all(10), child: Text('${_fmtKg(reducingTotal)} kg', softWrap: false, overflow: TextOverflow.fade)),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Icon(isMatch ? Icons.check_circle : Icons.error, color: isMatch ? Colors.green : Colors.red, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(isMatch ? 'ตรงกัน' : 'ไม่ตรงกัน \n(ต่าง ${_fmtKg(diff)} kg)', overflow: TextOverflow.ellipsis, softWrap: false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ตรวจสอบรายวันเทียบรายเดือน',
              style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: cmpYear,
                  decoration: const InputDecoration(labelText: 'ปี', border: OutlineInputBorder()),
                  items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                  onChanged: (v) => setState(() => cmpYear = v ?? cmpYear),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: cmpMonth,
                  decoration: const InputDecoration(labelText: 'เดือน', border: OutlineInputBorder()),
                  items: months
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(DateFormat('LLLL', 'th_TH').format(DateTime(2000, m, 1))),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => cmpMonth = v ?? cmpMonth),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: const StadiumBorder()),
              onPressed: cmpLoading ? null : _loadMonthlyCompare,
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: cmpLoading
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('ตรวจสอบ'),
            ),
          ),
          if (cmpData != null) ...[
            const SizedBox(height: 14),
            Text('เดือน ${_thaiMonthLabel(cmpYear, cmpMonth)}',
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            buildTable(),
            const SizedBox(height: 8),
            const Text('หมายเหตุ: ใช้ความคลาดเคลื่อน ±0.01 kg ในการพิจารณาค่าตรงกัน'),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: primaryColor, title: const Text('ตรวจสอบค่าพลังงาน')),
      body: ListView(padding: const EdgeInsets.all(16), children: [_buildComparePicker()]),
    );
  }
}
