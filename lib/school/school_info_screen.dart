import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolInfoScreen extends StatelessWidget {
  final String schoolId;

  const SchoolInfoScreen({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('School Information')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Schools').doc(schoolId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          var schoolData = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text('School Name: ${schoolData!['name']}', style: const TextStyle(fontSize: 18)),
              Text('Address: ${schoolData['address']}', style: const TextStyle(fontSize: 18)),
              Text('Principal: ${schoolData['principal']}', style: const TextStyle(fontSize: 18)),
            ],
          );
        },
      ),
    );
  }
}
