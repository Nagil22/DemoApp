import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolDetailsScreen extends StatelessWidget {
  final String schoolId;

  const SchoolDetailsScreen({
    super.key,
    required this.schoolId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('School Details'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('School not found'));
          }

          final schoolData = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard('School Information', schoolData),
                const SizedBox(height: 20),
                _buildFeaturesCard(schoolData['config']?['features'] ?? {}),
                const SizedBox(height: 20),
                _buildAdminCard(schoolData['adminId']),
                const SizedBox(height: 20),
                _buildStatsCard(schoolId),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(String title, Map<String, dynamic> data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Name', data['name'] ?? 'N/A'),
            _buildInfoRow('Code', data['code'] ?? 'N/A'),
            _buildInfoRow('Type', (data['type'] ?? 'N/A').toUpperCase()),
            _buildInfoRow('Status', data['status'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildFeaturesCard(Map<String, dynamic> features) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Features',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...features.entries.map((entry) => ListTile(
              leading: Icon(
                entry.value ? Icons.check_circle : Icons.cancel,
                color: entry.value ? Colors.green : Colors.red,
              ),
              title: Text(
                entry.key.replaceAll(RegExp(r'([A-Z])'), ' \$1')
                    .toLowerCase()
                    .capitalize(),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(String? adminId) {
    if (adminId == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No admin assigned'),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(adminId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final adminData = snapshot.data!.data() as Map<String, dynamic>?;
        if (adminData == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Admin data not found'),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'School Admin',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Name', adminData['username'] ?? 'N/A'),
                _buildInfoRow('Email', adminData['email'] ?? 'N/A'),
                _buildInfoRow('Status', adminData['status'] ?? 'N/A'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsCard(String schoolId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('schoolId', isEqualTo: schoolId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final users = snapshot.data!.docs;
        int teachers = 0;
        int students = 0;
        int parents = 0;

        for (var user in users) {
          final userData = user.data() as Map<String, dynamic>;
          switch (userData['role']) {
            case 'teacher':
              teachers++;
              break;
            case 'student':
              students++;
              break;
            case 'parent':
              parents++;
              break;
          }
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Total Users', users.length.toString()),
                _buildInfoRow('Teachers', teachers.toString()),
                _buildInfoRow('Students', students.toString()),
                _buildInfoRow('Parents', parents.toString()),
              ],
            ),
          ),
        );
      },
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}