import 'package:demo/widgets/new_bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ParentDashboardScreen extends StatefulWidget {
  final String username;
  final String userId;

  const ParentDashboardScreen({
    super.key,
    required this.username,
    required this.userId, required String schoolId, required String schoolName,
  });

  @override
  ParentDashboardScreenState createState() => ParentDashboardScreenState();
}

List<IconData> navIcons = [
  Icons.grade,
  Icons.calendar_today,
  Icons.notifications,
  Icons.account_balance_wallet
];

List<String> navTitle = [
  'Grades',
  'Attendance',
  'Notifications',
  'Payments'
];



class ParentDashboardScreenState extends State<ParentDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<String> _childrenIds = [];
  String? _selectedChildId;
  int currentIndex = 0;
  int selectedIndex = 0;

  void _onNavItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchChildrenIds();
  }

  void _fetchChildrenIds() async {
    var userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    if (userDoc.exists) {
      setState(() {
        _childrenIds = List<String>.from(userDoc.data()!['childrenIds'] ?? []);
        if (_childrenIds.isNotEmpty) {
          _selectedChildId = _childrenIds.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Parent Dashboard - ${widget.username}', style: const TextStyle(fontSize: 20),),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildChildSelector(),
          Expanded(
            child: _bodySections(selectedIndex),
          ),
          //   Create Bottom Navigation bar
        Align(
            alignment: Alignment.bottomCenter,
            child: NewBottomNavBar(
                currentIndex: selectedIndex,
                icons: navIcons,
                titles: navTitle,
              onTapped: _onNavItemTapped,
            )
        )
        ],
      ),
    );
  }

  Widget _buildChildSelector() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: DropdownButton<String>(
        value: _selectedChildId,
        icon: const Icon(Icons.perm_identity_outlined),
        hint: const Text('Click to select a child'),
        isExpanded: true,
        underline: Container(
          height: 2,
            color: Colors.grey,
        ),
        items: _childrenIds.map((String childId) {
          return DropdownMenuItem<String>(
            value: childId,
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(childId).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Text('Loading...');
                }
                if (snapshot.hasError) {
                  return const Text('Error');
                }
                return Text(snapshot.data!['username'] ?? 'Unknown');
              },
            ),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedChildId = newValue;
          });
        },
      ),
    );
  }

  Widget _buildGradesSection() {
    if (_selectedChildId == null) {
      return const Center(child: Text('Please select a child to see grades'));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('grades')
          .where('studentId', isEqualTo: _selectedChildId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Something went wrong'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var grades = snapshot.data!.docs;
        return ListView.builder(
          itemCount: grades.length,
          itemBuilder: (context, index) {
            var grade = grades[index].data() as Map<String, dynamic>;
            return ListTile(
              title: Text(grade['subject']),
              subtitle: Text('Grade: ${grade['grade']}'),
              trailing: Text('Date: ${DateFormat('yyyy-MM-dd').format((grade['date'] as Timestamp).toDate())}'),
            );
          },
        );


      },
    );
  }

  Widget _buildAttendanceSection() {
    if (_selectedChildId == null) {
      return const Center(child: Text('Please select a child to view attendance'));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('studentId', isEqualTo: _selectedChildId)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Something went wrong'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var attendanceRecords = snapshot.data!.docs;
        return ListView.builder(
          itemCount: attendanceRecords.length,
          itemBuilder: (context, index) {
            var record = attendanceRecords[index].data() as Map<String, dynamic>;
            return ListTile(
              title: Text(DateFormat('yyyy-MM-dd').format((record['date'] as Timestamp).toDate())),
              subtitle: Text(record['status']),
              leading: Icon(
                record['status'] == 'Present' ? Icons.check_circle : Icons.cancel,
                color: record['status'] == 'Present' ? Colors.green : Colors.red,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationsSection() {
    if (_selectedChildId == null) {
      return const Center(child: Text('Please select a child to send notifications'));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', whereIn: [_selectedChildId, widget.userId])
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Something went wrong'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var notifications = snapshot.data!.docs;
        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            var notification = notifications[index].data() as Map<String, dynamic>;
            return ListTile(
              title: Text(notification['title']),
              subtitle: Text(notification['message']),
              trailing: Text(DateFormat('yyyy-MM-dd – kk:mm').format((notification['timestamp'] as Timestamp).toDate())),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentsSection() {
    if (_selectedChildId == null) {
      return const Center(child: Text('Please select a child to make payment'));
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('wallets')
          .doc(_selectedChildId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Something went wrong'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var walletData = snapshot.data!.data() as Map<String, dynamic>?;
        return Column(
          children: [
            Card(
              child: ListTile(
                title: const Text('Current Balance'),
                subtitle: Text('\$${walletData?['balance'] ?? 0.0}'),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('transactions')
                    .where('userId', isEqualTo: _selectedChildId)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Something went wrong'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var transactions = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      var transaction = transactions[index].data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(transaction['description']),
                        subtitle: Text(DateFormat('yyyy-MM-dd – kk:mm').format((transaction['timestamp'] as Timestamp).toDate())),
                        trailing: Text('\$${transaction['amount']}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
  Widget _bodySections(section){
    switch (section){
      case 0:
        return _buildGradesSection();

      case 1:
        return _buildAttendanceSection();

      case 2:
        return _buildNotificationsSection();

      case 3:
        return _buildPaymentsSection();

      default:
       return _buildGradesSection();
    }

  }
  // Widget _bottomNavBar(){
  //   return Container(
  //     height: 65,
  //     margin: const EdgeInsets.only(
  //       right: 24,
  //       left: 24,
  //       bottom: 24,
  //     ),
  //     decoration: BoxDecoration(
  //         color: Colors.white,
  //         borderRadius: BorderRadius.circular(20),
  //         boxShadow: [
  //           BoxShadow(
  //               color: Colors.black.withAlpha(20),
  //               blurRadius: 20,
  //               spreadRadius: 10
  //           )
  //         ]
  //     ),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.center,
  //       mainAxisAlignment: MainAxisAlignment.center,
  //       children: navIcons.map((icon){
  //         int index = navIcons.indexOf(icon);
  //         bool isSelected = selectedIndex == index;
  //         return Material(
  //           color: Colors.transparent,
  //           child: GestureDetector(
  //             onTap: (){
  //               setState((){
  //                 selectedIndex = index;
  //               });
  //             },
  //             child: SingleChildScrollView(
  //               child: Column(
  //                 children: [
  //                   Container(
  //                     alignment: Alignment.center,
  //                     margin: const EdgeInsets.only(
  //                       top: 15,
  //                       bottom: 0,
  //                       left: 30,
  //                       right: 30,
  //                     ),
  //                     child: Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 25,),
  //                   ),
  //                   Text(
  //                       navTitle[index],
  //                       style: TextStyle(color: isSelected ? Colors.blue : Colors.grey, fontSize: 10)
  //                   ),
  //                   const SizedBox(
  //                     height: 10,
  //                   )
  //                 ],
  //               ),
  //             ),
  //           ),
  //         );
  //       }).toList(),
  //     ),
  //   );
  // }
}

