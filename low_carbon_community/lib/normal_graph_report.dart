import 'dart:convert';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportEmissionPage extends StatefulWidget {
  const ReportEmissionPage({super.key});

  @override
  State<ReportEmissionPage> createState() => _ReportEmissionPageState();
}

class _ReportEmissionPageState extends State<ReportEmissionPage> {
  final Color primaryColor = const Color(0xFF6FB188);

  DateTime? startDate;
  DateTime? endDate;
  Map<String, dynamic>? data;
  bool loading = false;

  String _fmtApi(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _fmtUi(DateTime d) => DateFormat('dd/MM/yyyy', 'th_TH').format(d);

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th_TH');
    startDate = DateTime.now();
    endDate = DateTime.now();
    _loadReport(); // โหลดทันทีเมื่อเข้า
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

  Future<void> _loadReport() async {
    if (startDate == null || endDate == null) return;
    if (endDate!.isBefore(startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('วันสิ้นสุดต้องไม่น้อยกว่าวันเริ่มต้น')),
      );
      return;
    }

    setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final homeCode = prefs.getInt('home_Code') ?? 0;

      final uri = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/report/range-summary'
        '?home_Code=$homeCode&start=${_fmtApi(startDate!)}&end=${_fmtApi(endDate!)}',
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
          final totals = (meta is Map && meta['totals'] is Map)
              ? Map<String, dynamic>.from(meta['totals'])
              : <String, dynamic>{};

          final double tCo2 =
              (totals['co2'] is num) ? (totals['co2'] as num).toDouble() : 0.0;
          final double tCh4 =
              (totals['ch4'] is num) ? (totals['ch4'] as num).toDouble() : 0.0;
          final double tN2o =
              (totals['n2o'] is num) ? (totals['n2o'] as num).toDouble() : 0.0;
          final double tReducing = (totals['reducing_total'] is num)
              ? (totals['reducing_total'] as num).toDouble()
              : 0.0;
          final double tNet = (totals['net_co2'] is num)
              ? (totals['net_co2'] as num).toDouble()
              : 0.0;

          setState(() {
            data = {
              'rows': (rows is List) ? rows : <dynamic>[],
              'meta': (meta is Map) ? meta : <String, dynamic>{},
              'emissions': {
                'co2': tCo2,
                'ch4': tCh4,
                'n2o': tN2o,
                'sum_all_gases': tCo2 + tCh4 + tN2o,
              },
              'reducing_total': tReducing,
              'net': {'net_co2': tNet},
              'daily': (rows is List) ? rows : <dynamic>[],
            };
          });
        } else {
          setState(() => data = {
                'rows': <dynamic>[],
                'meta': <String, dynamic>{},
                'emissions': null,
                'reducing_total': 0.0,
                'net': {'net_co2': 0.0},
                'daily': <dynamic>[],
              });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดรายงานไม่สำเร็จ: ${res.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ผิดพลาด: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ===== UI helpers (ยกมาจากหน้าเดิม) =====
  BarChartGroupData _bar(int x, double y) => BarChartGroupData(
        x: x,
        barRods: [BarChartRodData(toY: y, width: 22, borderRadius: BorderRadius.circular(6))],
      );

  Widget _co2BarChart({required double co2, required double reducing, required double net}) {
    final values = [co2, reducing, net];
    final maxY = (values.reduce((a, b) => a > b ? a : b) * 1.2).clamp(1.0, double.infinity);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('กราฟสรุป (CO₂ / ลด / สุทธิ)',
              style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                gridData: FlGridData(show: true),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        final labels = ['CO₂', 'ลด', 'สุทธิ'];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(idx >= 0 && idx < labels.length ? labels[idx] : '',
                              style: const TextStyle(fontSize: 12)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [_bar(0, co2), _bar(1, reducing), _bar(2, net)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryPieCard() {
    final Map<String, dynamic> totals =
        (data?['meta'] is Map && data!['meta']['totals'] is Map)
            ? Map<String, dynamic>.from(data!['meta']['totals'])
            : <String, dynamic>{};

    final List<Map<String, dynamic>> items = (totals['CatePie'] is List)
        ? List<Map<String, dynamic>>.from(
            (totals['CatePie'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
        : <Map<String, dynamic>>[];

    if (items.isEmpty) return const SizedBox.shrink();

    double asDouble(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0.0);
    final double sum = items.fold<double>(0.0, (s, it) => s + asDouble(it['value']));
    final List<Color> palette = <Color>[
      primaryColor, const Color(0xFFFFC107), const Color(0xFF607D8B), const Color(0xFF8BC34A),
      const Color(0xFF03A9F4),
    ];
    final sections = <PieChartSectionData>[
      for (int i = 0; i < items.length; i++)
        PieChartSectionData(
          color: palette[i % palette.length],
          value: asDouble(items[i]['value']),
          title: (() {
            final v = asDouble(items[i]['value']);
            final pct = sum > 0 ? (v / sum * 100) : 0.0;
            return pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '';
          })(),
          radius: 70,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          showTitle: true,
        ),
    ];

    String fmtKg(num v) => v.toStringAsFixed(2);

    return _card(
      title: 'สัดส่วนการปล่อยตามประเภท',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(sections: sections, centerSpaceRadius: 38, sectionsSpace: 2, startDegreeOffset: -90),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: List.generate(items.length, (i) {
              final label = '${items[i]['label']}';
              final v = asDouble(items[i]['value']);
              final pct = sum > 0 ? (v / sum * 100) : 0.0;
              final color = palette[i % palette.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('$label (${fmtKg(v)} kg, ${pct.toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _dailyChart(List<dynamic> dailyRows) {
    final list = dailyRows.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (list.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: _box(),
        child: const Text('—'),
      );
    }

    String dateLabel(Map<String, dynamic> m) {
      final raw = (m['label'] ?? m['day'] ?? '').toString();
      try {
        final d = DateTime.parse(raw);
        return DateFormat('dd/MM', 'th_TH').format(d);
      } catch (_) {
        return raw;
      }
    }

    double numOf(Map<String, dynamic> m, String k) {
      final v = m[k];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    double niceNum(double x, {bool round = false}) {
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

    String fmtY(double v) => (v % 1 == 0) ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

    final maxValue = list.fold<double>(0.0, (mx, it) {
      final a = numOf(it, 'total_CO2');
      final b = numOf(it, 'reducing');
      return [mx, a, b].reduce((x, y) => x > y ? x : y);
    });
    final rawMax = (maxValue == 0 ? 1.0 : maxValue * 1.2);
    final niceMaxY = niceNum(rawMax, round: false);
    final yStep = niceNum(niceMaxY / 5, round: true);

    const double barWidth = 10;
    const double barsSpace = 6;
    const double groupPad = 26;
    final double perGroupWidth = (barWidth * 2) + barsSpace + groupPad;

    final paddedMaxY = niceMaxY + yStep * 0.2;

    final double minWidth = MediaQuery.of(context).size.width - 32;
    final double contentWidth = (list.length * perGroupWidth) > minWidth
        ? (list.length * perGroupWidth)
        : minWidth;

    const double labelBoxWidth = 58;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _box(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('กราฟรายวัน (ปล่อย / ลด)',
              style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          SizedBox(
            height: 350,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: contentWidth,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    minY: 0,
                    maxY: paddedMaxY,
                    gridData: FlGridData(
                      show: true,
                      drawHorizontalLine: true,
                      drawVerticalLine: true,
                      horizontalInterval: yStep,
                      verticalInterval: 1,
                      getDrawingHorizontalLine: (v) => FlLine(color: Colors.black12, strokeWidth: 1),
                      getDrawingVerticalLine: (v) =>
                          FlLine(color: Colors.black12.withOpacity(0.35), strokeWidth: 0.5, dashArray: [4, 3]),
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
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        tooltipRoundedRadius: 8,
                        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        tooltipMargin: 8,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final item = list[group.x.toInt()];
                          final date = dateLabel(item);
                          final label = rodIndex == 0 ? 'ปล่อย' : 'ลด';
                          return BarTooltipItem(
                            '$date\n$label: ${rod.toY.toStringAsFixed(2)} kg',
                            const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                            textAlign: TextAlign.center,
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          interval: yStep,
                          getTitlesWidget: (value, meta) {
                            if (value < 0 || value > niceMaxY + 1e-6) return const SizedBox.shrink();
                            return Text(fmtY(value));
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          reservedSize: 60,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= list.length) return const SizedBox.shrink();
                            final text = dateLabel(list[idx]);
                            const double angleRad = -0.6;
                            return Padding(
                              padding: const EdgeInsets.only(top: 26),
                              child: Transform.rotate(
                                angle: angleRad,
                                alignment: Alignment.topLeft,
                                child: SizedBox(
                                  width: labelBoxWidth,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(text,
                                        softWrap: false,
                                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: list.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final co2 = numOf(item, 'total_CO2');
                      final reducing = numOf(item, 'reducing');
                      return BarChartGroupData(
                        x: idx,
                        barsSpace: 6,
                        barRods: [
                          BarChartRodData(toY: co2, width: 10, borderRadius: BorderRadius.circular(4), color: Colors.redAccent),
                          BarChartRodData(toY: reducing, width: 10, borderRadius: BorderRadius.circular(4), color: Colors.green),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _box() => BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      );

  Widget _card({required String title, required Widget child}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: _box(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );

  Widget _dateBox(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(color: const Color(0xFFEFF3F0), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? emissions =
        (data?['emissions'] is Map) ? Map<String, dynamic>.from(data!['emissions']) : null;

    final double reducing =
        (data?['reducing_total'] is num) ? (data!['reducing_total'] as num).toDouble() : 0.0;

    final double net =
        (data?['net'] is Map && (data!['net']['net_co2'] is num)) ? (data!['net']['net_co2'] as num).toDouble() : 0.0;

    return Scaffold(
      appBar: AppBar(backgroundColor: primaryColor, title: const Text('รายงานการปล่อยก๊าซ')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
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
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: const StadiumBorder()),
                      onPressed: loading ? null : _loadReport,
                      child: loading
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.search_rounded, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (emissions != null)
                    _co2BarChart(
                      co2: (emissions['co2'] as num).toDouble(),
                      reducing: reducing,
                      net: net,
                    ),

                  const SizedBox(height: 12),
                  if (data?['daily'] != null) _dailyChart(data!['daily']),
                  const SizedBox(height: 12),
                  if (data?['meta'] != null &&
                      data!['meta'] is Map &&
                      (data!['meta']['totals'] is Map) &&
                      (data!['meta']['totals']['CatePie'] is List))
                    _categoryPieCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
