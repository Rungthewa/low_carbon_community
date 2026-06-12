import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'AddCo2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'AddFoodFuelModal.dart';
import 'AddFoodWestModal.dart';
import 'AllHistory.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class FoodPage extends StatefulWidget {
  @override
  _FoodPageState createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> {
  final Color primaryColor = const Color(0xFF6FB188);
  List<Map<String, dynamic>> foodTypes = [];
  int? selectedFood;
  bool isModalVisible = false;

  final sizeController = TextEditingController();
  final quantityController = TextEditingController();

  List<Map<String, dynamic>> homeFoods = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    fetchFoodTypes();
    fetchHomeFoods();
  }

  int _asInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  int? _resolveFuelCode(Map<String, dynamic> item) {
    // 1) ลองอ่านรหัสจาก item ก่อน (รองรับทั้ง fuel_Code / food_Code และ String/int)
    final raw = item['fuel_Code'] ?? item['food_Code'];
    final parsed = int.tryParse(raw?.toString() ?? '');
    if (parsed != null &&
        foodTypes
            .any((m) => _asInt(m['fuel_Code'] ?? m['food_Code']) == parsed)) {
      return parsed; // โค้ดนี้มีในรายการจริง
    }

    // 2) ถ้าโค้ดไม่แมตช์ ให้ลองเทียบจากชื่อ
    final name = (item['fuel_Name'] ?? item['food_Name'])?.toString();
    if (name != null && name.isNotEmpty) {
      final found = foodTypes.firstWhere(
        (m) => (m['fuel_Name'] ?? m['food_Name'])?.toString() == name,
        orElse: () => {},
      );
      if (found.isNotEmpty) {
        return _asInt(found['fuel_Code'] ?? found['food_Code']);
      }
    }

    // 3) หาไม่เจอจริง ๆ
    return null;
  }

  Future<void> fetchFoodTypes() async {
    final response = await http.get(
      Uri.parse(
          'https://student.crru.ac.th/651463011/LowCarbonAPI/api/getFuelFood'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        foodTypes = List<Map<String, dynamic>>.from(data);
        selectedFood = foodTypes.isNotEmpty
            ? int.tryParse(foodTypes.first['fuel_Code'].toString())
            : null; // <-- ใช้ fuel_Code
      });
    } else {
      print("โหลดข้อมูลประเภทอาหารไม่สำเร็จ");
    }
  }

  Future<void> fetchHomeFoods() async {
    final prefs = await SharedPreferences.getInstance();
    final homeCode = prefs.getInt('home_Code') ?? 0;

    final url = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/getHomeFoodFuel/$homeCode');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          homeFoods = List<Map<String, dynamic>>.from(data);
        });
      } else {
        setState(() {
          homeFoods = [];
        });
      }
    } catch (e) {
      print("ไม่สามารถโหลดข้อมูลอาหาร: $e");
    }
  }

  void _openEditFoodDialog(Map<String, dynamic> item) async {
    if (foodTypes.isEmpty) {
      await fetchFoodTypes(); // ให้แน่ใจว่ามี items แล้ว
    }

    final int? currentFuel = _resolveFuelCode(item);
    final effRaw = item['size'];
    final String currentEff = (effRaw == null || effRaw.toString() == 'null')
        ? ''
        : effRaw.toString();

    await showDialog(
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
                      maxHeight: MediaQuery.of(context).size.height * 0.50,
                    ),
                    child: AddFoodFuelModal(
                      itemTypes: foodTypes,
                      selectedItem:
                          currentFuel, // ✅ ส่ง code ที่ “อยู่จริงใน items”
                      onItemChanged: (_) {},
                      onSubmitted: () {},
                      isEdit: true,
                      editingItemCode: (item['item_Code'] ?? item['Item_Code']),
                      initialEff: currentEff, // ✅ กัน "null" string
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (!mounted) return;
    await fetchHomeFoods();
  }

  Future<void> _deleteFoodItem(Map<String, dynamic> item) async {
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
          final res = await http.post(url,
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: {'item_Code': code.toString()});

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
            await fetchHomeFoods();
          } else {
            AwesomeDialog(
              context: context,
              dialogType: DialogType.error,
              animType: AnimType.scale,
              title: 'ลบไม่สำเร็จ',
              desc: res.body.isNotEmpty
                  ? res.body
                  : 'เกิดข้อผิดพลาดจากเซิร์ฟเวอร์',
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

  Widget _buildOptionCard({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: primaryColor.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainBody() {
    if (homeFoods.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: homeFoods.length,
          itemBuilder: (context, index) {
            final item = homeFoods[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddCo2Page(item: item, useType: 'F'),
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
                    // รูป + ปุ่มเมนูทับบนรูป (มุมขวาบน)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          // จัดรูปให้อยู่กลาง สูง 100
                          Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              height: 100,
                              child: (item['img'] != null &&
                                      '${item['img']}'.isNotEmpty)
                                  ? Image.network(item['img'],
                                      fit: BoxFit.contain)
                                  : Container(
                                      color: Colors.black12), // เผื่อไม่มีรูป
                            ),
                          ),
                          // ปุ่มเมนู
                          Positioned(
                            top: -6,
                            right: -14,
                            child: PopupMenuButton<String>(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _openEditFoodDialog(item);
                                } else if (value == 'delete') {
                                  _deleteFoodItem(item);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Center(
                                    child: Text(
                                      'แก้ไข',
                                      style: TextStyle(
                                        color: Color(0xFFFFB300), // amber[700]
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
                                  color: Color.fromARGB(255, 163, 163, 163)),
                              offset: const Offset(0, 8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                    Text(item['fuel_Name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                    Text('อาหาร',
                        style: TextStyle(color: primaryColor),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'เพิ่มการทำอาหาร',
              style: TextStyle(
                fontSize: 36,
                color: primaryColor.withOpacity(0.4),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Icon(
              Icons.emoji_people,
              size: 200,
              color: primaryColor.withOpacity(0.4),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: primaryColor),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('ทำอาหาร'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const HistoryPage(searchType: 'F')),
                    );
                  },
                  icon: const Icon(Icons.history,
                      size: 18, color: Color(0xFF3D8361)),
                  label: const Text(
                    'ประวัติ',
                    style: TextStyle(color: Color(0xFF3D8361)),
                  ),
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
          body: _buildMainBody(),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.white,
            child: Icon(Icons.add, color: primaryColor),
            onPressed: () {
              setState(() {
                isModalVisible = !isModalVisible;
              });
            },
          ),
        ),

        // ✅ Modal Overlay
        if (isModalVisible)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() => isModalVisible = false);
              },
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: GestureDetector(
                    onTap: () {}, // เพื่อไม่ให้ modal ปิดเมื่อคลิกในกล่อง
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildOptionCard(
                            title: 'เพิ่มเชื้อเพลิง',
                            subtitle: 'กรุณาระบุชนิดเชื้อเพลิง\nในการทำอาหาร',
                            onTap: () {
                              setState(() =>
                                  isModalVisible = false); // ปิด overlay menu
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
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.85,
                                        child: Material(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          color: Colors.white,
                                          child: Padding(
                                            padding: const EdgeInsets.all(24),
                                            child: SingleChildScrollView(
                                              child: ConstrainedBox(
                                                constraints: BoxConstraints(
                                                  maxHeight:
                                                      MediaQuery.of(context)
                                                              .size
                                                              .height *
                                                          0.50,
                                                ),
                                                child: AddFoodFuelModal(
                                                  itemTypes: foodTypes,
                                                  selectedItem: selectedFood,
                                                  onItemChanged: (value) =>
                                                      setState(() =>
                                                          selectedFood = value),
                                                  onSubmitted: fetchHomeFoods,
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
                          const SizedBox(height: 20),
                          _buildOptionCard(
                            title: 'เศษอาหาร',
                            subtitle: 'กรอกเศษอาหาร\nของคุณ',
                            onTap: () {
                              setState(() => isModalVisible = false);
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
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.85,
                                        child: Material(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          color: Colors.white,
                                          child: Padding(
                                            padding: const EdgeInsets.all(24),
                                            child: SingleChildScrollView(
                                              child: ConstrainedBox(
                                                constraints: BoxConstraints(
                                                  maxHeight:
                                                      MediaQuery.of(context)
                                                              .size
                                                              .height *
                                                          0.40,
                                                ),
                                                child: AddFoodWasteModal(
                                                  onSubmitted: fetchHomeFoods,
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
