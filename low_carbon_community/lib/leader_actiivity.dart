import 'dart:convert';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class VillageActivitiesPage extends StatefulWidget {
  const VillageActivitiesPage({super.key});

  @override
  State<VillageActivitiesPage> createState() => _VillageActivitiesPageState();
}

class _VillageActivitiesPageState extends State<VillageActivitiesPage> {
  final Color primaryColor = const Color(0xFF6FB188);

  DateTime? startDate;
  DateTime? endDate;
  Map<String, dynamic>? actData;
  bool actLoading = false;

  String _fmtApi(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _fmtUi(DateTime d) => DateFormat('dd/MM/yyyy', 'th_TH').format(d);

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th_TH');
    startDate = DateTime.now();
    endDate = DateTime.now();
    // **พฤติกรรมเดิม**: ยังไม่โหลดทันที รอผู้ใช้กดปุ่ม "โหลดกิจกรรมชุมชน"
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: endDate ?? DateTime(2100),
    );
    if (picked != null) setState(() => startDate = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? DateTime.now(),
      firstDate: startDate ?? DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => endDate = picked);
  }

  Future<void> _loadVillageActivities() async {
    if (startDate == null || endDate == null) return;

    setState(() => actLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final villageCode = prefs.getInt('village_code');

      if (villageCode == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบ village_code ในเครื่อง')),
        );
        return;
      }

      final uri = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/report/village-activity-summary'
        '?village_Code=$villageCode&start=${_fmtApi(startDate!)}&end=${_fmtApi(endDate!)}',
      );

      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          setState(() {
            actData = {
              'data': (decoded['data'] is Map)
                  ? decoded['data']
                  : <String, dynamic>{},
              'meta': (decoded['meta'] is Map)
                  ? decoded['meta']
                  : <String, dynamic>{},
            };
          });
        } else {
          setState(() => actData = {
                'data': <String, dynamic>{},
                'meta': <String, dynamic>{},
              });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดกิจกรรมไม่สำเร็จ: ${res.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => actLoading = false);
    }
  }

  BoxDecoration _box() => BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      );

  Widget _card({required String title, required Widget child}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: _box(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );

  Widget _dateBox(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF3F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  // ==== กราฟเส้นกิจกรรม + ตาราง (ยกโค้ดเดิมมา) ====
  Widget _activityLineChart() {
    final dataMap =
        (actData?['data'] is Map) ? Map<String, dynamic>.from(actData!['data']) : {};
    final List<dynamic> ts =
        (dataMap['timeseries'] is List) ? List<dynamic>.from(dataMap['timeseries']) : const [];

    if (ts.isEmpty) {
      return _card(title: 'กิจกรรมชุมชน (กราฟเส้น)', child: const Text('—'));
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < ts.length; i++) {
      final m = Map<String, dynamic>.from(ts[i] as Map);
      final y = (m['joined'] is num) ? (m['joined'] as num).toDouble() : 0.0;
      spots.add(FlSpot(i.toDouble(), y));
    }

    String labelAt(int i) {
      final m = Map<String, dynamic>.from(ts[i] as Map);
      final raw = (m['label'] ?? '').toString();
      try {
        final d = DateTime.parse(raw);
        return DateFormat('dd/MM', 'th_TH').format(d);
      } catch (_) {
        return raw;
      }
    }

    final maxY = spots.fold<double>(0.0, (mx, s) => math.max(mx, s.y));
    double _niceNum(double x, {bool round = false}) {
      if (x <= 0) return 1;
      final exp = (math.log(x) / math.ln10).floor();
      final f = x / math.pow(10, exp);
      double nf;
      if (round) {
        if (f < 1.5) nf = 1; else if (f < 3) nf = 2; else if (f < 7) nf = 5; else nf = 10;
      } else {
        if (f <= 1) nf = 1; else if (f <= 2) nf = 2; else if (f <= 5) nf = 5; else nf = 10;
      }
      return nf * math.pow(10, exp);
    }

    final niceMaxY = _niceNum((maxY == 0 ? 1 : maxY * 1.2), round: false);
    final yStep = _niceNum(niceMaxY / 5, round: true);

    final minWidth = MediaQuery.of(context).size.width - 32;
    final contentWidth = math.max(minWidth, ts.length * 50.0);

    return _card(
      title: 'กิจกรรมชุมชน (กราฟเส้น)',
      child: SizedBox(
        height: 260,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: niceMaxY,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: yStep,
                  drawVerticalLine: true,
                  verticalInterval: 1,
                  getDrawingVerticalLine: (v) => FlLine(
                    color: Colors.black12.withOpacity(0.35),
                    strokeWidth: 0.5,
                    dashArray: const [4, 3],
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    left: BorderSide(color: Color(0x22000000), width: 1),
                    bottom: BorderSide(color: Color(0x22000000), width: 1),
                    right: BorderSide(color: Colors.transparent, width: 0),
                    top: BorderSide(color: Colors.transparent, width: 0),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: yStep,
                      getTitlesWidget: (value, meta) => Text(
                        (value % 1 == 0) ? value.toStringAsFixed(0) : value.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 52,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= ts.length) return const SizedBox.shrink();
                        final text = labelAt(i);
                        return Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Transform.rotate(
                            angle: -0.6,
                            alignment: Alignment.topLeft,
                            child: SizedBox(
                              width: 46,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(text,
                                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (touchedSpots) => touchedSpots.map((tspt) {
                      final i = tspt.x.toInt();
                      final date = (i >= 0 && i < ts.length) ? labelAt(i) : '';
                      return LineTooltipItem(
                        '$date\nเข้าร่วม: ${tspt.y.toStringAsFixed(0)} คน',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _activityTableCard() {
    final dataMap =
        (actData?['data'] is Map) ? Map<String, dynamic>.from(actData!['data']) : {};
    final List<dynamic> table =
        (dataMap['table'] is List) ? List<dynamic>.from(dataMap['table']) : const [];

    if (table.isEmpty) {
      return _card(title: 'สรุปกิจกรรมชุมชน', child: const Text('—'));
    }

    return _card(
      title: 'สรุปกิจกรรมชุมชน',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 720),
          child: DataTable(
            columns: const [
              DataColumn(label: Text('กิจกรรม')),
              DataColumn(label: Text('วันที่')),
              DataColumn(label: Text('ต้องการ (คน)')),
              DataColumn(label: Text('เข้าร่วม (คน)')),
              DataColumn(label: Text('% สำเร็จ')),
              DataColumn(label: Text('หมายเหตุ')),
            ],
            rows: table.map((row) {
              final m = Map<String, dynamic>.from(row as Map);
              final name = (m['name'] ?? '').toString();
              final date = (m['date'] ?? '').toString();
              final target = (m['target'] is num)
                  ? (m['target'] as num).toInt()
                  : int.tryParse('${m['target']}') ?? 0;
              final actual = (m['actual'] is num)
                  ? (m['actual'] as num).toInt()
                  : int.tryParse('${m['actual']}') ?? 0;
              final pct = (m['percent'] is num)
                  ? (m['percent'] as num).toDouble()
                  : double.tryParse('${m['percent']}') ?? 0.0;
              final status = (m['status'] ?? '').toString();

              final ok = status == 'สำเร็จ';

              return DataRow(cells: [
                DataCell(Text(name, softWrap: false, overflow: TextOverflow.ellipsis)),
                DataCell(Text(() {
                  try {
                    final d = DateTime.parse(date);
                    return DateFormat('dd/MM/yyyy', 'th_TH').format(d);
                  } catch (_) {
                    return date;
                  }
                }())),
                DataCell(Text('$target')),
                DataCell(Text('$actual')),
                DataCell(Text('${pct.toStringAsFixed(0)}%')),
                DataCell(Row(
                  children: [
                    Icon(ok ? Icons.check_circle : Icons.error,
                        color: ok ? Colors.green : Colors.red, size: 18),
                    const SizedBox(width: 6),
                    Text(status),
                  ],
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(backgroundColor: primaryColor, title: const Text('ตรวจสอบกิจกรรมชุมชน')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickStart,
                  child: _dateBox('วันที่เริ่ม', startDate != null ? _fmtUi(startDate!) : 'เลือก'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: _pickEnd,
                  child: _dateBox('วันที่สิ้นสุด', endDate != null ? _fmtUi(endDate!) : 'เลือก'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: const StadiumBorder(),
              ),
              onPressed: actLoading ? null : _loadVillageActivities,
              icon: const Icon(Icons.event_available, color: Colors.white),
              label: actLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('โหลดกิจกรรมชุมชน'),
            ),
          ),
          const SizedBox(height: 12),

          if (actData != null) ...[
            _activityLineChart(),
            const SizedBox(height: 12),
            _activityTableCard(),
          ],
        ],
      ),
    );
  }
}
