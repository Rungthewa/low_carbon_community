import 'package:flutter/material.dart';
import 'mainHome.dart';
import 'itemMenu.dart';
import 'AccoutSetting.dart';
import 'Joiner.dart';
import 'normal_menu_Report.dart';
import '';

class Nav extends StatefulWidget {
  final int currentIndex;

  const Nav({Key? key, this.currentIndex = 0}) : super(key: key);
  @override
  _NavState createState() => _NavState();
}

class _NavState extends State<Nav> {
  int _currentIndex = 0;
  late List<Widget> _pages;

  final Color primaryColor = Color(0xFF6FB188);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;

    _pages = [
      _buildTabNavigator(MainHome(), 'MainHome'),
      _buildTabNavigator(JoinActivityListPage(), 'Community'),
      _buildTabNavigator(ItemMenu(), 'Activity'),
      _buildTabNavigator(ReportMenuPage(), 'Report'),
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
              icon: Icon(Icons.home),
              label: 'ครัวเรือน',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.groups),
              label: 'ชุมชน',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.checklist),
              label: 'กิจกรรม',
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
