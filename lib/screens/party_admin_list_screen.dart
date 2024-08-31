import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PartyAdminListScreen extends StatelessWidget {
  const PartyAdminListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('School Admins'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'admin')
            .snapshots(),
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
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('schools')
                    .doc(data['schoolId'])
                    .get(),
                builder: (context, schoolSnapshot) {
                  if (schoolSnapshot.connectionState == ConnectionState.done) {
                    Map<String, dynamic> schoolData = schoolSnapshot.data!.data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['name']),
                      subtitle: Text('School: ${schoolData['name']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.notification_add),
                        onPressed: () => _sendNotification(context, data['name'], data['email']),
                      ),
                    );
                  }
                  return const ListTile(
                    title: Text('Loading...'),
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }

  void _sendNotification(BuildContext context, String adminName, String adminEmail) {
    // Implement notification sending logic here
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Send Notification'),
          content: Text('Send notification to $adminName ($adminEmail)?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Send'),
              onPressed: () {
                // Implement the actual notification sending logic here
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Notification sent to $adminName')),
                );
              },
            ),
          ],
        );
      },
    );
  }
}