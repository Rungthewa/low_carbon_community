import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';


class HistoryPage extends StatefulWidget {
  final String searchType;
  const HistoryPage({Key? key, required this.searchType}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final Color primaryColor = const Color(0xFF6FB188);

  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();

  bool loading = false;
  List<Map<String, dynamic>> items = []; // แถวการใช้งานแบบแบน
  Map<String, List<Map<String, dynamic>>> grouped =
      {}; // กลุ่มตามวัน yyyy-MM-dd

  String _fmtApi(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _fmtUi(DateTime d) => DateFormat('dd/MM/yyyy', 'th_TH').format(d);
  String _fmtTime(DateTime d) => DateFormat('HH:mm').format(d);
  String _fmtDateThai(DateTime d) =>
      DateFormat('EEEE dd MMM yyyy', 'th_TH').format(d);

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th_TH').then((_) => _load());
    _load();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2023),
      lastDate: endDate, // ห้ามเกิน end
    );
    if (picked != null) {
      setState(() => startDate = picked);
    }
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate,
      firstDate: startDate, // ห้ามน้อยกว่า start
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => endDate = picked);
    }
  }

  Future<void> _load() async {
    if (endDate.isBefore(startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('วันสิ้นสุดต้องไม่น้อยกว่าวันเริ่มต้น')),
      );
      return;
    }
    setState(() => loading = true);
    print(widget.searchType);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final homeCode = prefs.getInt('home_Code') ?? 0;

      final uri = Uri.https(
        'student.crru.ac.th',
        '/651463011/LowCarbonAPI/api/Allhistory',
        {
          'home_Code': homeCode.toString(),
          'start': _fmtApi(startDate),
          'end': _fmtApi(endDate),
          'type': 'd',
          'searchType': widget.searchType, // <- ใส่ค่าที่ส่งมาจาก constructor
        },
      );

      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // debug
      // ignore: avoid_print
      print('↩ status: ${res.statusCode}');
      // ignore: avoid_print
      print('↩ body: ${res.body}');

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        // คาดโครงสร้าง: { success:true, data:[{ Date_time, user_name, item_name, amount, unit, CO2_emission, note }, ...] }
        final List<dynamic> rows =
            (decoded is Map && decoded['data'] is List) ? decoded['data'] : [];

        final parsed = rows.map<Map<String, dynamic>>((e) {
          final m = Map<String, dynamic>.from(e as Map);
          // parse datetime ปลอดภัย
          DateTime? dt;
          final raw = m['Date_time']?.toString() ?? '';
          try {
            dt = DateTime.parse(raw);
          } catch (_) {}
          m['_dt'] = dt; // เก็บ DateTime ไว้ใช้เรียง/format เวลา
          return m;
        }).toList();

        // เรียงใหม่สุดก่อน
        parsed.sort((a, b) {
          final da = a['_dt'] as DateTime?;
          final db = b['_dt'] as DateTime?;
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da); // desc
        });

        // จัดกลุ่มตาม "วันที่" (yyyy-MM-dd)
        final Map<String, List<Map<String, dynamic>>> g = {};
        for (final m in parsed) {
          final DateTime? dt = m['_dt'] as DateTime?;
          final key = dt != null
              ? DateFormat('yyyy-MM-dd').format(dt)
              : 'ไม่ทราบวันที่';
          (g[key] ??= []).add(m);
        }

        setState(() {
          items = parsed;
          grouped = g;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดประวัติไม่สำเร็จ: ${res.statusCode}')),
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

String _searchTypeLabel(String t) {
  switch (t) {
    case 'E': return 'เครื่องใช้ไฟฟ้า';
    case 'V': return 'ยานพาหนะ';
    case 'F': return 'อาหาร';
    default : return 'ทั้งหมด';
  }
}
  @override
  Widget build(BuildContext context) {
    final dayKeys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // วันล่าสุดก่อน (desc)
    final serachType = widget.searchType.toString();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text('ประวัติการใช้งาน (${_searchTypeLabel(widget.searchType)})'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickStart,
                    child: _dateBox('วันที่เริ่ม', _fmtUi(startDate)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickEnd,
                    child: _dateBox('วันที่สิ้นสุด', _fmtUi(endDate)),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: loading ? null : _load,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: const StadiumBorder(),
                    ),
                    child: loading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.search, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: dayKeys.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('— ไม่พบข้อมูล —')),
                      ],
                    )
                  : ListView.builder(
                      itemCount: dayKeys.length,
                      itemBuilder: (_, i) {
                        final key = dayKeys[i];
                        final DateTime? d = () {
                          try {
                            return DateTime.parse(key);
                          } catch (_) {
                            return null;
                          }
                        }();
                        final label = d != null ? _fmtDateThai(d) : key;
                        final rows = grouped[key]!;

                        return _daySection(title: label, rows: rows);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _daySection({
    required String title,
    required List<Map<String, dynamic>> rows,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // หัวการ์ด
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3F0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // รายการในวันนั้น
          ...rows.map((m) {
            final dt = m['_dt'] as DateTime?;
            final timeLabel = dt != null ? _fmtTime(dt) : '-:-';
            final homeItemCode = (m['Home_item_Code']).toString();
            final user = (m['user_name'] ?? m['User_Name'] ?? '').toString();
            final item = (m['item_name'] ?? m['Item_Name'] ?? m['name'] ?? '')
                .toString();
            final amt = (m['using_time'] ?? m['using_time'])?.toString();
            final co2 = (m['CO2_emission'] ?? m['co2'] ?? 0).toString();
            final type = (m['typeForItem'] ?? null).toString();

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(timeLabel, style: const TextStyle(fontSize: 11)),
              ),
              title: Text(user.isEmpty ? 'ไม่ทราบผู้ใช้' : user,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(homeItemCode == "0"?'เศษอาหาร':
                    type == 'C'
                      ? 'รถยนต์'
                      : type == 'M'
                          ? 'มอเตอร์ไซต์'
                          : item.isEmpty
                              ? '—'
                              : item),
                  if ((amt ?? '').isNotEmpty)
                    Text(
                        'ระยะการใช้: ${amt ?? '-'} ${type == 'C' || type == 'M' ? 'กิโลเมตร' : 'ชั่วโมง'}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('CO₂',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    '${double.tryParse(co2.toString())?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _dateBox(String label, String value) {
    return Container(
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
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
