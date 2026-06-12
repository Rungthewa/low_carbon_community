import 'package:flutter/material.dart';
import 'elecItem.dart';
import 'vehicleItem.dart';
import 'nav.dart';
import 'foodItem.dart';
import 'AllHistory.dart';

class ItemMenu extends StatelessWidget {
  final Color primaryColor = const Color(0xFF6FB188);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: const Text(
          'LOW CARBON COMMUNITY',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const SizedBox(height: 60),
                _buildMenuCard(
                  icon: Icons.electrical_services,
                  title: 'เครื่องใช้ไฟฟ้า',
                  subtitle: 'กรุณาบันทึกเครื่องใช้ไฟฟ้าที่เปิดใช้งาน',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ElecItemPage()),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _buildMenuCard(
                  icon: Icons.directions_car,
                  title: 'ยานพาหนะ',
                  subtitle: 'กรุณาระบุน้ำมันที่คุณใช้ในการเดินทาง',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => VehiclePage()),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _buildMenuCard(
                  icon: Icons.restaurant_menu,
                  title: 'อาหาร',
                  subtitle: 'กรอกการทำอาหารหรืออาหารเหลือกินของคุณ',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => FoodPage()),
                    );
                  },
                ),
              ],
            ),
          ),

          // ปุ่มรายงานที่มุมขวาบน
          Positioned(
            top: 16,
            right: 16,
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryPage(searchType: 'A',)),
                );
              },
              icon: Icon(Icons.history, size: 18, color: Color(0xFF3D8361)),
              label: Text(
                'ประวัติ',
                style: TextStyle(color: Color(0xFF3D8361)),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Color(0xFFDCF2E6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size(0, 50), // ย่อขนาดปุ่ม
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: Color(0xFF3D8361), size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3D8361))),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(fontSize: 18, color: Colors.black54)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
