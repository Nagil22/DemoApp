import 'package:flutter/material.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/school_dashboard_screen.dart';
import '../dash_screens/payments_screen.dart';

class NavItem {
  final int id;
  final IconData icon;
  final Widget destination;

  NavItem({required this.id, required this.icon, required this.destination});
}

class NavItems extends ChangeNotifier {
  int selectedIndex = 0;

  void updateSelectedIndex(int index) { // Renamed function to avoid conflict
    selectedIndex = index;
    notifyListeners();
  }

  List<NavItem> items = [
    NavItem(
      id: 1,
      icon: Icons.home,
      destination: const SchoolDashboardScreen(username: '', userId: '',),
    ),
    NavItem(
      id: 2,
      icon: Icons.person,
      destination: const ProfileScreen(username: '', email: '', userType: '', userId: '',),
    ),
    NavItem(
      id: 3,
      icon: Icons.payments,
      destination: const PaymentsScreen(),
    ),
    NavItem(
      id: 4,
      icon: Icons.settings,
      destination: const SettingsScreen(),
    ),
  ];

  void changeNavIndex({required int index}) {}

}
