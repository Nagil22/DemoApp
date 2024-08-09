import 'package:flutter/material.dart';

class NavProvider extends ChangeNotifier {
  int selectedIndex = 0; // Initial index set to 0 (Home screen)

  void changeNavIndex(int index) { // Function name remains the same
    selectedIndex = index;
    notifyListeners();
  }
}