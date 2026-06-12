import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MainLeaderPage extends StatefulWidget {
  const MainLeaderPage({Key? key}) : super(key: key);

  @override
  State<MainLeaderPage> createState() => _MainLeaderPageState();
}

class _MainLeaderPageState extends State<MainLeaderPage> {
  final Color primaryColor = const Color(0xFF6FB188);
  Map<String, dynamic>? leaderData;
  bool isLoading = true;
  List<Map<String, dynamic>> villageMembers = [];
  List<Map<String, dynamic>> filteredMembers = [];
  String searchText = '';
  String sortOrder = 'น้อยไปมาก';

  @override
  void initState() {
    super.initState();
    loadLeaderData();
  }

  void filterAndSortMembers() {
    List<Map<String, dynamic>> tempList = villageMembers.where((member) {
      final number = member['number'].toString();
      return number.contains(searchText);
    }).toList();

    tempList.sort((a, b) {
      final aCO2 = double.tryParse(a['total_co2'].toString()) ?? 0.0;
      final bCO2 = double.tryParse(b['total_co2'].toString()) ?? 0.0;
      return sortOrder == 'น้อยไปมาก'
          ? aCO2.compareTo(bCO2)
          : bCO2.compareTo(aCO2);
    });

    setState(() {
      filteredMembers = tempList;
    });
  }

  Future<void> loadVillageMembers() async {
    final prefs = await SharedPreferences.getInstance();
    final villageCode = prefs.getInt('village_code');

    if (villageCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบข้อมูลรหัสหมู่บ้าน')),
      );
      return;
    }

    final url = Uri.parse(
      'https://student.crru.ac.th/651463011/LowCarbonAPI/api/getVillageMember',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'Village_Code': villageCode.toString()},
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        villageMembers = List<Map<String, dynamic>>.from(jsonData['data']);
        filterAndSortMembers();
      } else {
        throw Exception('ไม่สามารถโหลดข้อมูลสมาชิกในหมู่บ้าน');
      }
    } catch (e) {
      print('Village member error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  Future<void> loadLeaderData() async {
    final prefs = await SharedPreferences.getInstance();
    final userCode = prefs.getInt('user_code');

    if (userCode == null) {
      // handle กรณีไม่มี user_code
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบข้อมูลผู้ใช้งาน')),
      );
      return;
    }

    final url = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/mainLeader?User_Code=$userCode');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        setState(() {
          leaderData = jsonData['data'];
          isLoading = false;
        });
        await prefs.setInt('village_code', leaderData!['Village_Code']);
        await loadVillageMembers();
      } else {
        throw Exception('โหลดข้อมูลไม่สำเร็จ');
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('LOW CARBON COMMUNITY'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Container(
                    height: screenSize.height, color: const Color(0xFFBDE2CB)),
                Positioned(
                  top: screenSize.height * 0.08,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: screenSize.height * 0.92,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        'ชุมชน${leaderData?['Village_Name'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'การปล่อยก๊าซเรือนกระจกของชุมชนอยู่ที่ ${leaderData?['all_co2']?.toStringAsFixed(2) ?? '0.00'} kg CO₂e',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: sortOrder,
                                    decoration: InputDecoration(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 16),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'น้อยไปมาก',
                                          child: Text('น้อยไปมาก')),
                                      DropdownMenuItem(
                                          value: 'มากไปน้อย',
                                          child: Text('มากไปน้อย')),
                                    ],
                                    onChanged: (value) {
                                      if (value != null) {
                                        sortOrder = value;
                                        filterAndSortMembers();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: TextField(
                          onChanged: (value) {
                            searchText = value;
                            filterAndSortMembers();
                          },
                          decoration: InputDecoration(
                            hintText: 'ค้นหาตามบ้านเลขที่',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: primaryColor.withOpacity(0.3),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: filteredMembers.length,
                          itemBuilder: (context, index) {
                            final member = filteredMembers[index];
                            return _buildHouseRow(
                              member['number'].toString(),
                              member['name'] ?? '',
                              double.parse(member['total_co2'].toString())
                                  .toStringAsFixed(2),
                              member['rewarded'] == 1,
                              imageUrl: member['home_img'],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHouseRow(String number, String name, String co2, bool rewarded,
      {String? imageUrl}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: imageUrl != null
            ? CircleAvatar(backgroundImage: NetworkImage(imageUrl))
            : const CircleAvatar(child: Icon(Icons.home)),
        title: Text('บ้านเลขที่ $number'),
        subtitle: Text(name.isNotEmpty ? name : 'ยังไม่มีชื่อ'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$co2 kg CO₂e'),
            const SizedBox(height: 4),
            rewarded
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                      SizedBox(width: 4),
                      Icon(Icons.emoji_events,
                          color: Colors.blueAccent, size: 20),
                    ],
                  )
                : const Text('ยังไม่รับรางวัล',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
