import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HomeRankAllPage extends StatefulWidget {
  final Color primaryColor;
  const HomeRankAllPage({
    super.key,
    required this.primaryColor,
  });

  @override
  State<HomeRankAllPage> createState() => _HomeRankAllPageState();
}

class _HomeRankAllPageState extends State<HomeRankAllPage> {
  Map<String, dynamic>? data;
  bool loading = false;

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final userCode = prefs.getInt('user_code');

      if (userCode == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบ user_code ในเครื่อง')),
        );
        return;
      }

      final uri = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/report/home-rank'
        '?user_code=$userCode&limit=0', // 0 = เอาทั้งหมด
      );

      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          setState(() => data = Map<String, dynamic>.from(decoded));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'โหลดอันดับทั้งหมดไม่สำเร็จ: ${res.statusCode}\n${res.body}'),
          ),
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

  @override
  Widget build(BuildContext context) {
    final dataMap = (data?['data'] is Map)
        ? Map<String, dynamic>.from(data!['data'])
        : <String, dynamic>{};
    final List<dynamic> list = (dataMap['list'] is List)
        ? List<dynamic>.from(dataMap['list'])
        : const [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.primaryColor,
        title: const Text('อันดับครัวเรือนในชุมชนทั้งหมด'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? const Center(child: Text('—'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final m = Map<String, dynamic>.from(list[i] as Map);

                    // ฟิลด์จาก home-rank
                    final rank = m['rank'] ?? '-';
                    final homeNo = (m['home_number'] ?? '').toString();
                    final total = ((m['total_reducing'] is num)
                            ? (m['total_reducing'] as num).toDouble()
                            : double.tryParse('${m['total_reducing']}') ?? 0.0)
                        .toStringAsFixed(2);
                    final last = (m['last_activity'] ?? '').toString();

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.black12,
                        child: Text('$rank'),
                      ),
                      title: Text('บ้านเลขที่ $homeNo'),
                      subtitle: last.isEmpty ? null : Text('อัปเดต: $last'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$total kg',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          // ถ้าอยากแสดงอย่างอื่นเพิ่มตรงนี้ได้
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
