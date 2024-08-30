import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/screens/school_dashboard_screen.dart';

class SchoolListScreen extends StatelessWidget {
  const SchoolListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schools'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('schools').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              Map<String, dynamic> data = document.data()! as Map<String, dynamic>;
              return ListTile(
                title: Text(data['name']),
                subtitle: Text(data['location']),
                onTap: () => _navigateToSchoolDashboard(context, document.id, data['name']),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  void _navigateToSchoolDashboard(BuildContext context, String schoolId, String schoolName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SchoolDashboardScreen(schoolId: schoolId, schoolName: schoolName, username: '', userId: '',),
      ),
    );
  }
}