import 'package:flutter/material.dart';
import 'village_rank.dart';
import 'leader_report.dart';
import 'leader_actiivity.dart';

class LeaderReportMenuPage extends StatelessWidget {
  const LeaderReportMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6FB188);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('เมนูรายงาน (ชุมชน)'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // อันดับชุมชน
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.emoji_events, color: primaryColor),
              title: const Text('อันดับชุมชน'),
              subtitle: const Text('อันดับ + คะแนนลดก๊าซ + ดูทั้งหมด'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VillageRankPage()),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // กราฟรายงานในชุมชน
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.cloud, color: primaryColor),
              title: const Text('กราฟรายงานในชุมชน'),
              subtitle: const Text('เลือกช่วงวัน + กราฟสรุป/รายวัน'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VillageEmissionReportPage()),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ตรวจสอบกิจกรรมชุมชน
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.event_available, color: primaryColor),
              title: const Text('ตรวจสอบกิจกรรมชุมชน'),
              subtitle: const Text('โหลดกิจกรรม + กราฟเส้น + ตารางสรุป'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VillageActivitiesPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
