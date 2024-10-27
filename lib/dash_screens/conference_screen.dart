import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UniversalConferenceScreen extends StatelessWidget {
  final String userId;
  final String schoolId;
  final String userType;
  final String username;

  const UniversalConferenceScreen({
    super.key,
    required this.userId,
    required this.schoolId,
    required this.userType,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conferences'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('conferences')
            .where(userType == 'teacher' ? 'teacherId' : 'parentId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var conferences = snapshot.data?.docs ?? [];

          return ListView.builder(
            itemCount: conferences.length,
            itemBuilder: (context, index) {
              var conference = conferences[index].data() as Map<String, dynamic>;
              return ListTile(
                title: Text(userType == 'teacher' ? conference['parentName'] : conference['teacherName'] ?? 'Unknown'),
                subtitle: Text('Status: ${conference['status']}'),
                trailing: conference['status'] == 'pending'
                    ? ElevatedButton(
                  onPressed: () => _showConferenceActionDialog(context, conferences[index].id, conference),
                  child: Text(userType == 'teacher' ? 'Respond' : 'Cancel'),
                )
                    : null,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showScheduleConferenceDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showConferenceActionDialog(BuildContext context, String conferenceId, Map<String, dynamic> conference) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Conference Request'),
          content: Text(userType == 'teacher'
              ? '${conference['parentName']} has requested a conference. Do you want to accept or decline?'
              : 'Do you want to cancel this conference request?'),
          actions: [
            if (userType == 'teacher') ...[
              TextButton(
                child: const Text('Decline'),
                onPressed: () {
                  _updateConferenceStatus(conferenceId, 'declined');
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Accept'),
                onPressed: () {
                  _updateConferenceStatus(conferenceId, 'accepted');
                  Navigator.of(context).pop();
                },
              ),
            ] else
              TextButton(
                child: const Text('Cancel Request'),
                onPressed: () {
                  _updateConferenceStatus(conferenceId, 'cancelled');
                  Navigator.of(context).pop();
                },
              ),
          ],
        );
      },
    );
  }

  void _updateConferenceStatus(String conferenceId, String status) {
    FirebaseFirestore.instance
        .collection('schools')
        .doc(schoolId)
        .collection('conferences')
        .doc(conferenceId)
        .update({'status': status});
  }

  void _showScheduleConferenceDialog(BuildContext context) {
    final TextEditingController recipientEmailController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Schedule Conference'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: recipientEmailController,
                decoration: InputDecoration(
                  labelText: userType == 'teacher' ? 'Parent Email' : 'Teacher Email',
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (pickedDate != null && pickedDate != selectedDate) {
                    selectedDate = pickedDate;
                  }
                },
                child: const Text('Select Date'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final TimeOfDay? pickedTime = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (pickedTime != null && pickedTime != selectedTime) {
                    selectedTime = pickedTime;
                  }
                },
                child: const Text('Select Time'),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Schedule'),
              onPressed: () {
                _scheduleConference(context, recipientEmailController.text, selectedDate, selectedTime);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _scheduleConference(BuildContext context, String recipientEmail, DateTime date, TimeOfDay time) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scheduling conference...')),
      );

      QuerySnapshot recipientQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: recipientEmail)
          .where('schoolCode', isEqualTo: schoolId)
          .where('role', isEqualTo: userType == 'teacher' ? 'parent' : 'teacher')
          .limit(1)
          .get();

      if (recipientQuery.docs.isEmpty) {
        throw Exception('Recipient not found');
      }

      String recipientId = recipientQuery.docs.first.id;
      String recipientName = recipientQuery.docs.first['name'] ?? 'Unknown';

      DocumentReference conferenceRef = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('conferences')
          .add({
        'teacherId': userType == 'teacher' ? userId : recipientId,
        'teacherName': userType == 'teacher' ? username : recipientName,
        'parentId': userType == 'parent' ? userId : recipientId,
        'parentName': userType == 'parent' ? username : recipientName,
        'dateTime': DateTime(date.year, date.month, date.day, time.hour, time.minute),
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'schoolId': schoolId,
      });

      // Verify that the conference was added
      DocumentSnapshot conferenceSnapshot = await conferenceRef.get();
      if (conferenceSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conference scheduled successfully')),
        );
      } else {
        throw Exception('Conference was not added to Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling conference: $e');
      } // Log the error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scheduling conference: $e')),
      );
    }
  }
}