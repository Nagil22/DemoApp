import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/screens/profile_screen.dart';
import 'package:demo/screens/school_list_screen.dart';
import 'package:demo/screens/admin_list_screen.dart';
import 'package:demo/screens/company_admin_list_screen.dart';
import 'package:demo/screens/party_admin_list_screen.dart';
import 'package:demo/screens/admin_creation_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  final String username;
  final String email;
  final String userId;

  const AdminPanelScreen({
    super.key,
    required this.username,
    required this.userId,
    required this.email,
  });

  @override
  AdminPanelScreenState createState() => AdminPanelScreenState();
}

class AdminPanelScreenState extends State<AdminPanelScreen> {
  int _selectedIndex = 0;
  late String username;
  late String email;

  @override
  void initState() {
    super.initState();
    username = widget.username;
    email = widget.email;
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    setState(() {
      username = userDoc['name'];
      email = userDoc['email'];
    });
  }

  List<Widget> get _widgetOptions => <Widget>[
    const SchoolListScreen(),
    const AdminListScreen(),
    const CompanyAdminListScreen(),
    const PartyAdminListScreen(),
    ProfileScreen(
        userId: widget.userId,
        username: username,
        email: email,
        userType: "Super Admin", accentColor: Colors.blueAccent,
    ),
    const AdminCreationScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Super Admin Panel', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20)),
        backgroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: 'Schools',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings),
            label: 'Admins',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business),
            label: 'Companies',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.gavel),
            label: 'Parties',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add),
            label: 'Create Admin',
          ),
        ],
        currentIndex: _selectedIndex,
        backgroundColor: Colors.blue,
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}