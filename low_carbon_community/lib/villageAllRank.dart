import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class VillageRankAllPage extends StatefulWidget {
  final Color primaryColor;
  final DateTime start;
  final DateTime end;
  const VillageRankAllPage({
    super.key,
    required this.primaryColor,
    required this.start,
    required this.end,
  });

  @override
  State<VillageRankAllPage> createState() => _VillageRankAllPageState();
}

class _VillageRankAllPageState extends State<VillageRankAllPage> {
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
      final villageCode = prefs.getInt('village_code');

      if (villageCode == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบ village_code ในเครื่อง')),
        );
        return;
      }

      final uri = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/report/village-rank'
        '?village_Code=$villageCode&start=${_fmt(widget.start)}&end=${_fmt(widget.end)}&limit=0',
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
          SnackBar(content: Text('โหลดอันดับทั้งหมดไม่สำเร็จ: ${res.statusCode}\n${res.body}')),
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
        title: const Text('อันดับชุมชนทั้งหมด'),
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
                    final rank = m['rank'] ?? '-';
                    final name = (m['village_name'] ?? '').toString();
                    final total = ((m['total_reducing'] is num)
                    ? (m['total_reducing'] as num).toDouble()
                    : double.tryParse('${m['total_reducing']}') ?? 0.0)
                .toStringAsFixed(2);
                    final member = (m['member_count'] ?? 0).toString();
                    final last = (m['last_activity'] ?? '').toString();
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.black12,
                        child: Text('$rank'),
                      ),
                      title: Text(name),
                      subtitle: Text('อัปเดต: $last'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$total kg', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('สมาชิก $member', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
