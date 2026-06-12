import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'AddVehicleModal.dart';
import 'AddCo2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'AllHistory.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class VehiclePage extends StatefulWidget {
  @override
  _VehiclePageState createState() => _VehiclePageState();
}

class _VehiclePageState extends State<VehiclePage> {
  final Color primaryColor = const Color(0xFF6FB188);
  List<Map<String, dynamic>> itemTypes = [];
  int? selectedItem;

  final sizeController = TextEditingController(); // not used
  final quantityController = TextEditingController(); // plate no.
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    fetchItemTypes();
    fetchHomeItems();
  }

  Future<void> fetchItemTypes() async {
    final response = await http.get(
      Uri.parse(
          'https://student.crru.ac.th/651463011/LowCarbonAPI/api/getFuel'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        itemTypes = List<Map<String, dynamic>>.from(data);
        selectedItem =
            itemTypes.isNotEmpty ? itemTypes.first['fuel_Code'] : null;
      });
    } else {
      print("โหลด Fuel ไม่สำเร็จ");
    }
  }

  int? _asInt(dynamic v) => (v is int) ? v : int.tryParse(v.toString());

  int? resolveFuelCode(
      Map<String, dynamic> item, List<Map<String, dynamic>> itemTypes) {
    // ลองหลายคีย์
    for (final key in ['fuel_Code', 'fuel_code', 'Fuel_Code']) {
      if (item.containsKey(key)) return _asInt(item[key]);
    }
    // เผื่อฝังใน object
    if (item['fuel'] is Map) {
      final f = item['fuel'] as Map;
      for (final key in ['fuel_Code', 'fuel_code']) {
        if (f.containsKey(key)) return _asInt(f[key]);
      }
    }
    // หาโดยชื่อ ถ้ามี
    final name = item['fuel_Name']?.toString();
    if (name != null && name.isNotEmpty) {
      final hit = itemTypes.firstWhere(
        (it) => (it['fuel_Name']?.toString() ?? '') == name,
        orElse: () => {},
      );
      if (hit.isNotEmpty) return _asInt(hit['fuel_Code']);
    }
    return null;
  }

  List<Map<String, dynamic>> homeItems = [];

  Future<void> fetchHomeItems() async {
    final prefs = await SharedPreferences.getInstance();
    final homeCode = prefs.getInt('home_Code') ?? 0;

    final url = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/getHomeVehicle/$homeCode');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          homeItems = List<Map<String, dynamic>>.from(data);
        });
      } else {
        setState(() {
          homeItems = [];
        });
      }
    } catch (e) {
      print("ไม่สามารถโหลดข้อมูลยานพาหนะ: $e");
    }
  }

  void _openEditVehicleDialog(Map<String, dynamic> item) {
    final int? currentFuel =
        resolveFuelCode(item, itemTypes); // ✅ ได้โค้ดที่ตรงกับ itemTypes
    final String currentPlate =
        (item['plate_no'] ?? item['location_name'] ?? '').toString();
    final String currentEff =
        (item['km_per_litre'] ?? item['size'] ?? '').toString();
    final String currentRadio = (item['type'] ?? 'C').toString();

    quantityController.text = currentPlate;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        content: Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: Material(
              borderRadius: BorderRadius.circular(30),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.60,
                    ),
                    child: AddVehicleModal(
                      itemTypes: itemTypes,
                      selectedItem: currentFuel, // ✅ ส่ง int ที่ตรงแน่ ๆ
                      sizeController: sizeController,
                      quantityController: quantityController,
                      onItemChanged: (_) {},
                      onSubmitted: () {
                        Navigator.pop(context);
                        fetchHomeItems();
                      },
                      isEdit: true,
                      editingItemCode: (item['item_Code'] ?? item['Item_Code']),
                      initialRadio: currentRadio,
                      initialEff: currentEff,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteVehicleItem(Map<String, dynamic> item) async {
    final code = item['item_Code'] ?? item['Item_Code'];
    if (code == null) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.scale,
        title: 'ไม่พบรหัสรายการ',
        desc: 'ไม่สามารถลบได้เนื่องจากไม่พบรหัสรายการ',
        btnOkOnPress: () {},
      ).show();
      return;
    }

    // ยืนยันการลบ
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: 'ลบรายการ',
      desc: 'ต้องการลบรายการนี้หรือไม่?',
      btnCancelText: 'ไม่',
      btnOkText: 'ใช่',
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        setState(() => _submitting = true);
        try {
          final url = Uri.parse(
              'https://student.crru.ac.th/651463011/LowCarbonAPI/api/deleteHomeItem');
          final res = await http.post(url, headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
          }, body: {
            'item_Code': code.toString()
          });

          if (!mounted) return;

          if (res.statusCode == 200) {
            AwesomeDialog(
              context: context,
              dialogType: DialogType.success,
              animType: AnimType.scale,
              title: 'ลบสำเร็จ',
              desc: 'ลบรายการเรียบร้อยแล้ว',
              btnOkOnPress: () {},
            ).show();
            await fetchHomeItems();
          } else {
            AwesomeDialog(
              context: context,
              dialogType: DialogType.error,
              animType: AnimType.scale,
              title: 'ลบไม่สำเร็จ',
              desc: res.body.isNotEmpty ? res.body : 'เกิดข้อผิดพลาดจากเซิร์ฟเวอร์',
              btnOkOnPress: () {},
            ).show();
          }
        } catch (e) {
          if (!mounted) return;
          AwesomeDialog(
            context: context,
            dialogType: DialogType.error,
            animType: AnimType.scale,
            title: 'ข้อผิดพลาดเครือข่าย',
            desc: '$e',
            btnOkOnPress: () {},
          ).show();
        } finally {
          if (mounted) setState(() => _submitting = false);
        }
      },
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('รายการยานพาหนะ'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const HistoryPage(searchType: 'V')),
                );
              },
              icon:
                  const Icon(Icons.history, size: 18, color: Color(0xFF3D8361)),
              label: const Text('ประวัติ',
                  style: TextStyle(color: Color(0xFF3D8361))),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFDCF2E6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(0, 50),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
      body: homeItems.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: homeItems.length,
                itemBuilder: (context, index) {
                  final item = homeItems[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddCo2Page(item: item, useType: 'V'),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // รูป + ปุ่มเมนูทับบนรูป (อยู่มุมขวาบน)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: SizedBox(
                                    height: 100,
                                    child: Image.asset(
                                      item['type'] == 'C'
                                          ? 'images/car.png'
                                          : 'images/motorcye.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: -6,
                                  right: -14,
                                  child: PopupMenuButton<String>(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        _openEditVehicleDialog(item);
                                      } else if (value == 'delete') {
                                        _deleteVehicleItem(item);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Center(
                                          child: Text(
                                            'แก้ไข',
                                            style: TextStyle(
                                              color: Color(0xFFFFB300),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Center(
                                          child: Text(
                                            'ลบ',
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    icon: const Icon(Icons.more_vert,
                                        color:
                                            Color.fromARGB(255, 163, 163, 163)),
                                    offset: const Offset(0, 8),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),
                          Text(
                            item['location_name'] ?? item['plate_no'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          Text(item['fuel_Name'],
                              style: TextStyle(color: Colors.black),
                              textAlign: TextAlign.center),
                          Text('เดินทาง',
                              style: TextStyle(color: primaryColor),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'เพิ่มยานพาหนะ',
                    style: TextStyle(
                      fontSize: 36,
                      color: primaryColor.withOpacity(0.4),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Icon(Icons.emoji_people,
                      size: 200, color: primaryColor.withOpacity(0.4)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        child: Icon(Icons.add, color: primaryColor),
        onPressed: () {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                contentPadding: EdgeInsets.zero,
                content: Center(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.85,
                    child: Material(
                      borderRadius: BorderRadius.circular(30),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.60,
                            ),
                            child: AddVehicleModal(
                              itemTypes: itemTypes,
                              selectedItem: selectedItem,
                              sizeController: sizeController,
                              quantityController: quantityController,
                              onItemChanged: (value) =>
                                  setState(() => selectedItem = value),
                              onSubmitted: fetchHomeItems,
                              // โหมดเพิ่ม (ค่า default)
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
