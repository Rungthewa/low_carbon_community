import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'joinActivity.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'homeAllRank.dart';
import 'package:intl/intl.dart';

class MainHome extends StatefulWidget {
  @override
  _MainHomeState createState() => _MainHomeState();
}

class _MainHomeState extends State<MainHome> {
  final Color primaryColor = Color(0xFF6FB188);
  String homeNumber = '-';
  double gasCO2 = 0;
  double gasCH4 = 0;
  double gasN2O = 0;
  double total_gas = 0;
  bool rankLoading = false;
  Map<String, dynamic>? rankData;
  double totalEmission = 0;
  bool isLoading = true;
  String? imageUrl;
  int unreadCount = 0;
  int joined_count = 0;
  List<dynamic> notifications = [];
  bool isPopupOpened = false;
  List<Map<String, dynamic>> badgeList = [];

  ImageProvider<Object> getProfileImage() {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return NetworkImage(imageUrl!);
    } else {
      return AssetImage('images/default.png');
    }
  }

  @override
  void initState() {
    super.initState();
    fetchMainHomeData();
    fetchNotifications();
    fetchRewardBadges();
    fetchGasData();
    fetchAllGasData();
    _loadHomeRank(limit: 5);
  }

  DateTime? _parseDateTime(String? date, String? time) {
    if (date == null || date.trim().isEmpty) return null;
    final d = date.trim();
    final t = (time ?? '').trim();
    // รูปแบบที่ API ส่งมาคาดว่า "YYYY-MM-DD" และ "HH:mm:ss"
    // จะได้ "YYYY-MM-DD HH:mm:ss" ซึ่ง DateTime.parse รองรับ
    final s = t.isNotEmpty ? '$d $t' : d;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  bool _canOpenJoin(Map item) {
    final now = DateTime.now();
    final dateStr = item['activity_date']?.toString();
    final startStr = item['activity_start']?.toString();
    final endStr = item['activity_end']?.toString();

    final start = _parseDateTime(dateStr, startStr);
    final end = _parseDateTime(dateStr, endStr);

    if (start != null && now.isBefore(start)) {
      // ยังไม่ถึงเวลาเริ่ม
      return false;
    }
    if (end != null && now.isAfter(end)) {
      // เลยเวลาสิ้นสุดแล้ว
      return false;
    }
    // ถ้าไม่มีเวลา (start/end) ให้ผ่านไปได้
    return true;
  }

  Future<void> fetchMainHomeData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final userCode = prefs.getInt('user_code') ?? 0;

    const apiUrl =
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/mainHome';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'User_Code': userCode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          homeNumber = data['Home_number'] ?? '-';
          imageUrl = data['img'];
          isLoading = false;
        });
      } else {
        print('Error: ${response.body}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Exception: $e');
      setState(() => isLoading = false);
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    // รองรับทั้ง "yyyy-MM-dd" และ "yyyy-MM-dd HH:mm:ss"
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw; // ถ้า parse ไม่ได้ ก็แสดงดิบๆ
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  Future<void> markAllAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final userCode = prefs.getInt('user_code') ?? 0;

    const apiUrl =
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/markAllAsRead';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'user_code': userCode}),
      );

      if (response.statusCode != 200) {
        print('Failed to mark all as read: ${response.body}');
      }
    } catch (e) {
      print('Exception in markAllAsRead: $e');
    }
  }

  Future<void> fetchNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final userCode = prefs.getInt('user_code') ?? 0;

    const apiUrl =
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/showNotification';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'user_code': userCode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          unreadCount = data['unread_count'] ?? 0;
          notifications = data['notifications'] ?? [];
          joined_count = data['joined_count'] ?? [];
        });
      } else {
        print('Notification Error: ${response.body}');
      }
    } catch (e) {
      print('Exception fetching notifications: $e');
    }
  }

  String _notifIdOf(Map item) {
    final u = item['User_Code'] ?? item['user_code'] ?? '';
    final a = item['activity_Code'] ?? '';
    return '$u-$a';
  }

  // 1) ถามยืนยันครั้งเดียวที่นี่
  Future<void> _confirmDelete(Map item) async {
    final int activityCode = item['activity_Code'] ?? 0;

    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: 'ลบการแจ้งเตือน',
      desc: 'ต้องการลบการแจ้งเตือนนี้หรือไม่?',
      btnCancelText: 'ยกเลิก',
      btnOkText: 'ลบ',
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        await _deleteNotification(activityCode);
      },
    ).show();
  }

// 2) ยิงลบ + โชว์ผลเพียงครั้งเดียว แล้วรีเฟรช noti/badge
  Future<void> _deleteNotification(int activityCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final userCode = prefs.getInt('user_code') ?? 0;

      final uri = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/notification/delete',
      );

      final res = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'user_code': userCode,
          'activity_code': activityCode,
        }),
      );

      if (res.statusCode == 200) {
        // รีเฟรชรายการและตัวเลข badge ให้ทันที
        await fetchNotifications();
        if (mounted) setState(() {});

        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.scale,
          title: 'ลบสำเร็จ',
          desc: 'ลบการแจ้งเตือนเรียบร้อยแล้ว',
          btnOkOnPress: () {},
        ).show();
      } else {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.leftSlide,
          title: 'ลบไม่สำเร็จ',
          desc: 'รหัส ${res.statusCode}\n${res.body}',
          btnOkOnPress: () {},
        ).show();
      }
    } catch (e) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.bottomSlide,
        title: 'ข้อผิดพลาด',
        desc: 'เกิดข้อผิดพลาด: $e',
        btnOkOnPress: () {},
      ).show();
    }
  }

  Future<void> _loadHomeRank({int limit = 5}) async {
    setState(() => rankLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final villageCode = prefs.getInt('village_code');
      final userCode = prefs.getInt('user_code'); // <-- ต้องมี

      if (villageCode == null || userCode == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบ village_code หรือ user_code')),
        );
        return;
      }

      final uri = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/report/home-rank'
        '?village_Code=$villageCode'
        '&limit=$limit'
        '&user_code=$userCode', // <-- ส่ง user_code
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
          SnackBar(
              content:
                  Text('โหลดอันดับไม่สำเร็จ: ${res.statusCode}\n${res.body}')),
        );
      }
    } catch (e) {
      debugPrint('home-rank error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ผิดพลาด: $e')),
      );
    } finally {
      if (mounted) setState(() => rankLoading = false);
    }
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }

  Widget _homeRankCard() {
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
      return _card(
        title: 'อันดับครัวเรือนในชุมชน',
        child: const Text('—'),
      );
    }

    // ----- แถว "อันดับของฉัน"
    Widget _selfTile() {
      if (self == null) return const SizedBox.shrink();

      // ลองพิมพ์ดูว่าฝั่ง API ส่งอะไรมาบ้าง
      // debugPrint('SELF: ${jsonEncode(self)}');

      final rank = self['rank'] ?? '-';
      final homeNo = (self['home_number'] ?? '').toString();

      // รองรับทั้ง total_reducing และ total
      final totalVal = _toDouble(self['total_reducing'] ?? self['total']);
      final total = totalVal.toStringAsFixed(2);

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
              child: Text(
                'บ้านเลขที่ $homeNo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text('$total kg'),
          ],
        ),
      );
    }

    Widget _rewardChip(String url) {
      if (url.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            width: 24,
            height: 24,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.image_not_supported, size: 18),
          ),
        ),
      );
    }

    return _card(
      title: 'อันดับครัวเรือนในชุมชน\nที่ลดก๊าสเรือนกระจกมากที่สุด',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _selfTile(),
          const Divider(),
          ...list.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            final rank = m['rank'] ?? '-';
            final homeNo = (m['home_number'] ?? '').toString();
            final name = (m['household_name'] ?? 'ครัวเรือน').toString();
            final total = ((m['total_reducing'] is num)
                    ? (m['total_reducing'] as num).toDouble()
                    : double.tryParse('${m['total_reducing']}') ?? 0.0)
                .toStringAsFixed(2);
            final last = (m['last_activity'] ?? '').toString();

            return ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: Colors.black12,
                child: Text('$rank'),
              ),
              title: Text(
                'บ้านเลขที่ $homeNo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              // ⬇️ แทน subtitle: Text('')
              subtitle: Builder(builder: (_) {
                // รูปเดียวจาก key 'reward_img'
                final rewardImg = (m['reward_img'] ?? '').toString();

                // หลายรูปจาก key 'rewards' (รายการที่แต่ละตัวมี field 'img')
                final rewards = (m['rewards'] is List)
                    ? List<Map<String, dynamic>>.from(m['rewards'])
                    : const <Map<String, dynamic>>[];

                if (rewards.isNotEmpty) {
                  return SizedBox(
                    height: 28,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: rewards.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) =>
                          _rewardChip((rewards[i]['img'] ?? '').toString()),
                    ),
                  );
                }
                if (rewardImg.isNotEmpty) {
                  return Row(children: [_rewardChip(rewardImg)]);
                }
                return const SizedBox.shrink();
              }),

              trailing: Text(
                '$total kg',
                style: const TextStyle(fontWeight: FontWeight.w600),
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
                      builder: (_) => HomeRankAllPage(
                            primaryColor: primaryColor,
                          )),
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

  Future<void> fetchRewardBadges() async {
    final prefs = await SharedPreferences.getInstance();
    final homeCode = prefs.getInt('home_Code') ?? 0;

    final url = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/getRewardByHome/$homeCode');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          badgeList = List<Map<String, dynamic>>.from(data['rewards']);
        });
        print("Badge Rewards: ${data['rewards']}");
      } else {
        print("โหลด reward ไม่สำเร็จ");
      }
    } catch (e) {
      print("Exception: $e");
    }
  }

  Future<void> fetchGasData() async {
    final prefs = await SharedPreferences.getInstance();
    final userCode = prefs.getInt('user_code') ?? 0;

    final url = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/getGasByHome/$userCode');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          gasCO2 = (data['CO2_emission'] ?? 0).toDouble();
          gasCH4 = (data['CH4_emission'] ?? 0).toDouble();
          gasN2O = (data['N2O_emission'] ?? 0).toDouble();
        });
      } else {
        print('Failed to load gas data');
      }
    } catch (e) {
      print("Exception fetching gas: $e");
    }
  }

  Future<void> fetchAllGasData() async {
    final prefs = await SharedPreferences.getInstance();
    final userCode = prefs.getInt('user_code') ?? 0;

    final url = Uri.parse(
        'https://student.crru.ac.th/651463011/LowCarbonAPI/api/allGasByHome/$userCode');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          total_gas = double.parse((data['total'] ?? 0).toStringAsFixed(2));
        });
      } else {
        print('Failed to load gas data');
      }
    } catch (e) {
      print("Exception fetching gas: $e");
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
      body: Stack(
        children: [
          Container(height: screenSize.height, color: Color(0xFFBDE2CB)),
          Positioned(
            top: screenSize.height * 0.08,
            left: 0,
            right: 0,
            child: Container(
              height: screenSize.height * 0.92,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 16,
            child: Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      )
                    ],
                  ),
                  child: PopupMenuButton<int>(
                    icon: Icon(Icons.notifications_none, color: primaryColor),
                    offset: const Offset(100, 40), // เลื่อนเมนูเยื้องไปทางซ้าย
                    color: const Color(0xFFF4F4F4),
                    onOpened: () {
                      setState(() {
                        isPopupOpened = true;
                      });
                    },

                    // ✅ เมื่อ popup ถูกปิดโดยไม่เลือก
                    onCanceled: () async {
                      await markAllAsRead();
                      await fetchNotifications();
                      setState(() {
                        isPopupOpened = false;
                      });
                    },
                    itemBuilder: (BuildContext context) {
                      if (notifications.isEmpty) {
                        return [
                          const PopupMenuItem<int>(
                            enabled: false,
                            child: Text('ไม่มีการแจ้งเตือน'),
                          ),
                        ];
                      }

                      return List<PopupMenuEntry<int>>.generate(
                        notifications.length,
                        (index) {
                          final item = notifications[index];

                          return PopupMenuItem<int>(
                            enabled:
                                false, // <<< สำคัญ: ไม่ให้แตะแล้วปิด popup เอง
                            padding: EdgeInsets.zero,
                            // ✅ ตัดคลิปเฉพาะบริเวณการ์ด ไม่ให้ล้นกรอบเมนู
                            child: ClipRect(
                              child: Slidable(
                                key: ValueKey(_notifIdOf(item)),
                                endActionPane: ActionPane(
                                  motion: const ScrollMotion(),
                                  children: [
                                    SlidableAction(
                                      onPressed: (_) => _confirmDelete(item),
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      icon: Icons.delete,
                                      label: 'ลบ',
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  onTap: () {
                                    final int activityCode =
                                        item['activity_Code'] ?? 0;
                                    final joined = item['join_status'] == 1;

                                    if (joined) {
                                      AwesomeDialog(
                                        context: context,
                                        dialogType: DialogType.error,
                                        animType: AnimType.scale,
                                        title: 'เข้าร่วมไม่สำเร็จ',
                                        desc: 'คุณได้เข้าร่วมกิจกรรมนี้แล้ว',
                                        btnOkOnPress: () {},
                                      ).show();
                                      return;
                                    }

                                    // ✅ เช็กช่วงเวลา: อนุญาตให้เข้าวันเดียวกันได้ (start <= now <= end)
                                    if (!_canOpenJoin(item)) {
                                      // แยกข้อความตามยังไม่เปิด/ปิดแล้วก็ได้ (ถ้าต้องการ)
                                      final now = DateTime.now();
                                      final start = _parseDateTime(
                                          item['activity_date']?.toString(),
                                          item['activity_start']?.toString());
                                      final end = _parseDateTime(
                                          item['activity_date']?.toString(),
                                          item['activity_end']?.toString());
                                      String msg =
                                          'กิจกรรมยังไม่เปิดให้เข้าร่วมในขณะนี้';
                                      if (start != null &&
                                          now.isBefore(start)) {
                                        msg =
                                            'กิจกรรมยังไม่เปิดให้เข้าร่วม (เริ่ม ${item['activity_start'] ?? '-'})';
                                      } else if (end != null &&
                                          now.isAfter(end)) {
                                        msg =
                                            'กิจกรรมปิดรับเข้าร่วมแล้ว (สิ้นสุด ${item['activity_end'] ?? '-'})';
                                      }

                                      AwesomeDialog(
                                        context: context,
                                        dialogType: DialogType.warning,
                                        animType: AnimType.scale,
                                        title: 'ไม่สามารถเข้าร่วมได้',
                                        desc: msg,
                                        btnOkOnPress: () {},
                                      ).show();
                                      return;
                                    }

                                    // ✅ ผ่านเงื่อนไข -> ไปหน้าเข้าร่วม
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => JoinActivityPage(
                                            activityCode: activityCode),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0, vertical: 4),
                                    child: Stack(
                                      // ✅ บังคับไม่ให้ลูกหลุดขอบ Stack
                                      clipBehavior: Clip.hardEdge,
                                      children: [
                                        Container(
                                          width: 260,
                                          padding: const EdgeInsets.all(12),
                                          margin: const EdgeInsets.only(top: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 4,
                                                offset: Offset(2, 2),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  if (item['reading'] == 0) ...[
                                                    const Icon(Icons.circle,
                                                        color: Colors.red,
                                                        size: 10),
                                                    const SizedBox(width: 6),
                                                  ],
                                                  Expanded(
                                                    child: Text(
                                                      item['activity_Name'] ??
                                                          'ไม่ระบุชื่อกิจกรรม',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.green,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item['Activity_detail'] ??
                                                    'ไม่มีรายละเอียด',
                                                style: const TextStyle(
                                                  color: Colors.green,
                                                  fontSize: 13,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    item['activity_date'] ??
                                                        '-',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                  Text(
                                                    "${item['Joined_count']}/${item['Count']}",
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    onSelected: (int index) {
                      final item = notifications[index];
                      final int activityCode = item['activity_Code'] ?? 0;
                      if (item['join_status'] == 1) {
                        AwesomeDialog(
                          context: context,
                          dialogType: DialogType.error,
                          animType: AnimType.scale,
                          title: 'เข้าร่วมไม่สำเร็จ',
                          desc: 'คุณได้เข้าร่วมกิจกรรมนี้แล้ว',
                          btnOkOnPress: () {},
                        ).show();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                JoinActivityPage(activityCode: activityCode),
                          ),
                        );
                      }
                    },
                  ),
                ),
                if (unreadCount > 0 && !isPopupOpened)
                  Positioned(
                    right: 1,
                    top: 1,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Center(
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned.fill(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : Column(
                    children: [
                      const SizedBox(height: 16),
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: getProfileImage(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'บ้านเลขที่ $homeNumber',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    )
                                  ],
                                ),
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'รางวัลที่ได้',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                    const SizedBox(
                                        height:
                                            8), // ระยะห่างระหว่างหัวข้อกับ badges
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: badgeList.map((badge) {
                                        // รองรับทั้งแบบซ้อนใน rewarded และแบบแปะตรงๆ
                                        final haveDateRaw =
                                            (badge['rewarded'] is Map &&
                                                    badge['rewarded']
                                                            ['Have_Date'] !=
                                                        null)
                                                ? badge['rewarded']['Have_Date']
                                                    .toString()
                                                : (badge['Have_Date'] ?? '')
                                                    .toString();

                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(right: 16),
                                          child: _badgeBox(
                                            badge['img'] ?? '',
                                            badge['title'] ?? '',
                                            haveDate: _formatDate(haveDateRaw),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    )
                                  ],
                                ),
                                padding: EdgeInsets.all(16),
                                child: _buildPieChartSection(),
                              ),
                              const SizedBox(height: 24),
                              _homeRankCard(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _badgeBox(String imageUrl, String label, {String? haveDate}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.network(
              imageUrl,
              height: 40,
              width: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (haveDate != null && haveDate.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            '$haveDate',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildPieChartSection() {
    double totalGas = gasCO2 + gasCH4 + gasN2O;
    double co2Percent = totalGas > 0 ? (gasCO2 / totalGas * 100) : 0;
    double ch4Percent = totalGas > 0 ? (gasCH4 / totalGas * 100) : 0;
    double n2oPercent = totalGas > 0 ? (gasN2O / totalGas * 100) : 0;
    String total2 = totalGas.toStringAsFixed(2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ก๊าซเรือนกระจกของครัวเรือน',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 2),
        Text(
          'ครัวเรือนของคุณได้ปล่อยก๊าซเรือนกระจกทั้งหมด $total2 kgCO₂e',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 1.3,
          child: PieChart(
            PieChartData(sections: _getSections()),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.spaceEvenly,
          runAlignment: WrapAlignment.center,
          spacing: 12, // ระยะห่างแนวนอน
          runSpacing: 8, // ระยะห่างแนวตั้งเวลาตัดบรรทัด
          children: [
            _gasRow('คาร์บอนไดออกไซด์ (CO₂)', gasCO2, Colors.redAccent),
            _gasRow('มีเทน (CH₄)', gasCH4, Colors.orangeAccent),
            _gasRow('ไนตรัสออกไซด์ (N₂O)', gasN2O, Colors.blue),
          ],
        )
      ],
    );
  }

  Widget _gasRow(String label, double percent, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // จุดสีระบุชนิดก๊าซ (เอาออกได้ถ้าไม่ต้องการ)
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),

          // ชื่อก๊าซยาวได้ ตัดบรรทัด/ย่อเอง
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 12),

          // เปอร์เซ็นต์ชิดขวา
          Text('${percent.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ],
      ),
    );
  }

  List<PieChartSectionData> _getSections() {
    double totalGas = gasCO2 + gasCH4 + gasN2O;
    double co2Percent = totalGas > 0 ? (gasCO2 / totalGas * 100) : 0;
    double ch4Percent = totalGas > 0 ? (gasCH4 / totalGas * 100) : 0;
    double n2oPercent = totalGas > 0 ? (gasN2O / totalGas * 100) : 0;
    String gasCO2fix = co2Percent.toStringAsFixed(2);
    String gasCH4fix = ch4Percent.toStringAsFixed(2);
    String gasN2Ofix = n2oPercent.toStringAsFixed(2);
    return [
      PieChartSectionData(
        value: gasCO2,
        color: Colors.redAccent,
        title: '$gasCO2fix%',
        radius: 50,
        titleStyle: TextStyle(fontSize: 10, color: Colors.white),
      ),
      PieChartSectionData(
        value: gasCH4,
        color: Colors.orangeAccent,
        title: '$gasCH4fix%',
        radius: 50,
        titleStyle: TextStyle(fontSize: 10, color: Colors.white),
      ),
      PieChartSectionData(
        value: gasN2O,
        color: Colors.blue,
        title: '$gasN2Ofix%',
        radius: 50,
        titleStyle: TextStyle(fontSize: 10, color: Colors.white),
      ),
    ];
  }
}
