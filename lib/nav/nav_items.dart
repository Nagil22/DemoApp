import 'package:demo/admin_screen.dart';
import 'package:flutter/material.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../dash_screens/calendar_screen.dart';
import '../dash_screens/payments_screen.dart';

class NavItem {
  final int id;
  final IconData icon;
  final Widget destination;

  NavItem({required this.id, required this.icon, required this.destination});
}

class NavItems extends ChangeNotifier {
  int selectedIndex = 0;

  void changeNavIndex({required int index}) {
    selectedIndex = index;
    notifyListeners();
  }

  List<NavItem> items = [
    NavItem(
      id: 1,
      icon: Icons.calendar_month,
      destination: const CalendarScreen(),
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
}
