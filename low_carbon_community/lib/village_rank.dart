import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'villageAllRank.dart';

class VillageRankPage extends StatefulWidget {
  const VillageRankPage({super.key, this.start, this.end});

  final DateTime? start;
  final DateTime? end;

  @override
  State<VillageRankPage> createState() => _VillageRankPageState();
}

class _VillageRankPageState extends State<VillageRankPage> {
  final Color primaryColor = const Color(0xFF6FB188);

  Map<String, dynamic>? rankData;
  bool rankLoading = false;

  DateTime get _start => widget.start ?? DateTime.now();
  DateTime get _end => widget.end ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadVillageRank();
  }

  Future<void> _loadVillageRank({int limit = 5}) async {
    setState(() => rankLoading = true);
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
        '?village_Code=$villageCode&limit=$limit',
      );

      final res = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          setState(() => rankData = Map<String, dynamic>.from(decoded));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดอันดับไม่สำเร็จ: ${res.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => rankLoading = false);
    }
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
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
  }

  Widget _villageRankCard() {
    final dataMap = (rankData?['data'] is Map)
        ? Map<String, dynamic>.from(rankData!['data'])
        : <String, dynamic>{};

    final List<dynamic> list = (dataMap['list'] is List)
        ? List<dynamic>.from(dataMap['list'])
        : const [];

    final Map<String, dynamic>? self = (dataMap['self'] is Map)
        ? Map<String, dynamic>.from(dataMap['self'])
        : null;

    if (list.isEmpty && self == null) {
      return _card(title: 'อันดับชุมชน', child: const Text('—'));
    }

    Widget _selfTile() {
      if (self == null) return const SizedBox.shrink();
      final rank = self['rank'] ?? '-';
      final name = (self['village_name'] ?? '').toString();
      final total = ((self['total_reducing'] is num)
                  ? (self['total_reducing'] as num).toDouble()
                  : double.tryParse('${self['total_reducing']}') ?? 0.0)
              .toStringAsFixed(2);
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF3F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: primaryColor,
              child: Text('$rank', style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Text('$total kg'),
          ],
        ),
      );
    }

    return _card(
      title: 'อันดับชุมชน \nการลดก๊าซเรือนกระจก',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _selfTile(),
          ...list.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            final rank = m['rank'] ?? '-';
            final name = (m['village_name'] ?? '').toString();
            final total = ((m['total_reducing'] is num)
                    ? (m['total_reducing'] as num).toDouble()
                    : double.tryParse('${m['total_reducing']}') ?? 0.0)
                .toStringAsFixed(2);
            final member = (m['member_count'] ?? 0).toString();
            final last = (m['last_activity'] ?? '').toString();
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: Colors.black12,
                child: Text('$rank'),
              ),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('อัปเดต: $last'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$total kg',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('สมาชิก $member', style: const TextStyle(fontSize: 12)),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VillageRankAllPage(
                      primaryColor: primaryColor,
                      start: _start,
                      end: _end,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.navigate_next),
              label: const Text('เพิ่มเติม'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(backgroundColor: primaryColor, title: const Text('อันดับชุมชน')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (rankLoading) const LinearProgressIndicator(minHeight: 2),
          _villageRankCard(),
        ],
      ),
    );
  }
}
