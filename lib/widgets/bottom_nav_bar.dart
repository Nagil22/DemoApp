// widgets/bottom_nav_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../nav/nav_items.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NavItems>(
      builder: (context, navItems, child) {
        return BottomNavigationBar(
          currentIndex: navItems.selectedIndex,
          onTap: (index) {
            navItems.changeNavIndex(index: index);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => navItems.items[index].destination,
              ),
            );
          },
          items: navItems.items.map((navItem) {
            return BottomNavigationBarItem(
              icon: Icon(navItem.icon),
              label: '',
            );
          }).toList(),
        );
      },
    );
  }
}
