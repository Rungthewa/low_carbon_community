import 'dart:async';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'package:intl/intl.dart';

const String kDailyLogUniqueName = 'dailyLogUnique';
const String kDailyLogTaskName   = 'dailyLogTask';

/// ตัว Dispatcher ที่ WorkManager จะเรียกตอนรันงานเบื้องหลัง
@pragma('vm:entry-point') // สำคัญมาก: ให้เรียกได้จาก isolate เบื้องหลัง
void dailyLogCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // ดึงข้อมูลผู้ใช้ที่เก็บไว้ (เช่น ตอนล็อกอิน)
      final prefs = await SharedPreferences.getInstance();
      final userCode    = prefs.getInt('user_code');
      final villageCode = prefs.getInt('village_code');

      // ถ้าไม่มี session ก็ไม่ต้องยิง (ถือว่าผ่านไปเฉย ๆ)
      if (userCode == null || villageCode == null) {
        return true;
      }

      final now = DateTime.now();
      final payload = {
        'user_code'   : userCode,
        'village_code': villageCode,
        'date'        : DateFormat('yyyy-MM-dd').format(now),
        'time'        : DateFormat('HH:mm:ss').format(now),
        'type'        : 'AUTO_DAILY_LOG',
      };

      final res = await ApiClient.postRequest('/daily-log', payload: payload);
      final ok = res.statusCode >= 200 && res.statusCode < 300;

      // ส่ง true ให้ WorkManager รู้ว่างานครั้งนี้สำเร็จ
      return ok;
    } catch (_) {
      // false = ให้ WorkManager จัดการ retry ตาม backoff policy
      return false;
    }
  });
}

/// คำนวณ delay จนถึง 22:00 ของวันนี้/พรุ่งนี้
Duration _delayUntil22() {
  final now = DateTime.now();
  var target = DateTime(now.year, now.month, now.day, 22);
  if (now.isAfter(target)) {
    target = target.add(const Duration(days: 1));
  }
  return target.difference(now);
}

/// เรียกครั้งเดียวตอนเริ่มแอป (หรือหลังล็อกอินก็ได้)
Future<void> scheduleDailyLog() async {
  await Workmanager().initialize(
    dailyLogCallbackDispatcher,
    isInDebugMode: false,
  );

  await Workmanager().registerPeriodicTask(
    kDailyLogUniqueName,           // ชื่อ unique work
    kDailyLogTaskName,             // ชื่อ task
    frequency: const Duration(days: 1),          // ทุก 24 ชม.
    initialDelay: _delayUntil22(),               // ให้รันรอบแรกตอน 22:00
    existingWorkPolicy: ExistingWorkPolicy.keep, // กันสมัครซ้ำ
    constraints: Constraints(
      networkType: NetworkType.connected,        // ต้องมีเน็ต
    ),
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: const Duration(minutes: 10),
    inputData: const {'reason': 'auto-daily-log'},
  );
}

/// ใช้หยุดงานถ้าต้องการ
Future<void> cancelDailyLog() =>
    Workmanager().cancelByUniqueName(kDailyLogUniqueName);
