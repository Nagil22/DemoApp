import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/school/admin_dashboard_screen.dart';
import 'package:demo/school/teacher_dashboard_screen.dart';
import 'package:demo/school/parent_dashboard_screen.dart';
import 'package:demo/school/student_dashboard_screen.dart';

class SchoolDashboardScreen extends StatelessWidget {
  final String username;
  final String userId;
  final String schoolCode;
  final String schoolName;

  const SchoolDashboardScreen({
    super.key,
    required this.username,
    required this.userId,
    required this.schoolCode,
    required this.schoolName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$schoolName Dashboards'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('schools').doc(schoolCode).get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }


          return ListView(
            children: [
              _buildDashboardTile(context, 'Admin Dashboard', Icons.admin_panel_settings, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminDashboardScreen(schoolCode: schoolCode, schoolName: schoolName, username: '', userId: '',),
                  ),
                );
              }),
              _buildDashboardTile(context, 'Teacher Dashboard', Icons.school, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TeacherDashboardScreen(schoolCode: schoolCode, schoolName: schoolName, username: '', userId: '', ),
                  ),
                );
              }),
              _buildDashboardTile(context, 'Parent Dashboard', Icons.family_restroom, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ParentDashboardScreen(schoolCode: schoolCode, schoolName: schoolName, username: '', userId: '',),
                  ),
                );
              }),
              _buildDashboardTile(context, 'Student Dashboard', Icons.person, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentDashboardScreen(schoolCode: schoolCode, schoolName: schoolName, username: '', userId: '',),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDashboardTile(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }
}