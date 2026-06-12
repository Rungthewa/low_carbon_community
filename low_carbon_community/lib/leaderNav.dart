import 'package:flutter/material.dart';
import 'mainLeader.dart';
import 'AccoutSetting.dart';
import 'leaderActivity.dart';
import 'leader_menu_report.dart';

class LeaderNav extends StatefulWidget {
  final int currentIndex;

  const LeaderNav({Key? key, this.currentIndex = 0}) : super(key: key);
  @override
  _LeaderNavState createState() => _LeaderNavState();
}

class _LeaderNavState extends State<LeaderNav> {
  int _currentIndex = 0;
  late List<Widget> _pages;

  final Color primaryColor = Color(0xFF6FB188);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;

    _pages = [
      _buildTabNavigator(MainLeaderPage(), 'MainHome'),
      _buildTabNavigator(LeaderActivityPage(), 'Community'),
      _buildTabNavigator(LeaderReportMenuPage(), 'Report'),
      _buildTabNavigator(AccountSettingPage(), 'Account'),
    ];
  }

  Widget _buildTabNavigator(Widget child, String navigatorKey) {
    return Navigator(
      key: PageStorageKey(navigatorKey),
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: primaryColor,
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.black,
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.holiday_village_rounded),
              label: 'จัดการชุมชน',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups),
              label: 'กิจกรรมชุมชน',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart),
              label: 'รายงาน',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'ฉัน',
            ),
          ],
        ),
      ),
    );
  }
}
