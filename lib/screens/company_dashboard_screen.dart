import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CompanyDashboardScreen extends StatelessWidget {
  final String username;
  final String userId;

  const CompanyDashboardScreen({
    super.key,
    required this.username,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    final String username = args['username'];
    final String userId = args['userId'];

    return Scaffold(
      appBar: AppBar(
        title: Text('Company Dashboard - Hello, $username!'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.pushNamed(context, '/notifications');
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('tasks').where('userId', isEqualTo: userId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = snapshot.data!.docs;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTaskSummary(tasks),
                const SizedBox(height: 20),
                const ListTile(
                  leading: Icon(Icons.work),
                  title: Text('Projects'),
                ),
                const ListTile(
                  leading: Icon(Icons.people),
                  title: Text('Teams'),
                ),
                const ListTile(
                  leading: Icon(Icons.analytics),
                  title: Text('Reports'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Implement logout functionality
                    FirebaseAuth.instance.signOut();
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text('Logout'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskSummary(List<QueryDocumentSnapshot> tasks) {
    int completedTasks = tasks.where((task) => task['completed'] == true).length;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blueAccent,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Task Summary',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Total Tasks: ${tasks.length}',
            style: const TextStyle(color: Colors.white),
          ),
          Text(
            'Completed Tasks: $completedTasks',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
