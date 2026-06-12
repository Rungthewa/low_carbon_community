import 'package:flutter/material.dart';
import 'normal_graph_report.dart';
import 'normal_compare.dart';

class ReportMenuPage extends StatelessWidget {
  const ReportMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6FB188);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('เมนูรายงาน'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.cloud, color: primaryColor),
              title: const Text('รายงานการปล่อยก๊าซ'),
              subtitle: const Text('เลือกช่วงวัน + กราฟสรุป/รายวัน + สัดส่วนตามประเภท'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportEmissionPage()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.bolt, color: primaryColor),
              title: const Text('ตรวจสอบค่าพลังงาน'),
              subtitle: const Text('ตรวจสอบรายวันเทียบรายเดือน (ElecMonthly vs Monthly)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportEnergyComparePage()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
