import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:demo/screens/profile_screen.dart';
import 'package:demo/structure.dart';
import 'dash_screens/school_management_screen.dart';

// ActivityLogger mixin to handle activity logging
mixin ActivityLogger {
  Future<void> logActivity(String userId, String username, String action, String details) async {
    try {
      await FirebaseFirestore.instance.collection('activity_log').add({
        'action': action,
        'details': details,
        'user': username,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error logging activity: $e');
      }
    }
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications', style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: const Center(
        child: Text('Super Admin Notifications'),
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget with ActivityLogger {
  final String userId;
  final String username;
  final Map<String, int> stats;
  final bool isLoading;

  const DashboardScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.stats,
    required this.isLoading,
  });



  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsGrid(),
          const SizedBox(height: 24),
          _buildRecentActivity(context),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          'Total Schools',
          stats['totalSchools'].toString(),
          Icons.school,
          Colors.blue,
        ),
        _buildStatCard(
          'Active Schools',
          stats['activeSchools'].toString(),
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatCard(
          'Total Users',
          stats['totalUsers'].toString(),
          Icons.people,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    logActivity(userId, username, 'Refresh Activity Log', 'Manual refresh of activity log');
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('activity_log')
                  .orderBy('timestamp', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No recent activity'));
                }

                var activities = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    var activity = activities[index].data() as Map<String, dynamic>;
                    String userInitial = (activity['user'] ?? 'U').toString();
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(userInitial.isNotEmpty ? userInitial[0].toUpperCase() : 'U'),
                      ),
                      title: Text(activity['action'] ?? 'Unknown action'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (activity['details'] != null)
                            Text(activity['details']),
                          Text(
                            activity['timestamp']?.toDate().toString() ?? 'No date',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

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

class AdminPanelScreenState extends State<AdminPanelScreen> with ActivityLogger {
  int _selectedIndex = 0;
  late String username;
  late String email;
  bool _isLoading = false;

  Map<String, int> _systemStats = {
    'totalSchools': 0,
    'activeSchools': 0,
    'totalUsers': 0,
  };

  @override
  void initState() {
    super.initState();
    username = widget.username;
    email = widget.email;
    _initializeSuperAdmin().then((_) {
      _fetchSystemStats();
      _logInitialAccess();
    });
  }


  Future<void> _logInitialAccess() async {
    await logActivity(
      widget.userId,
      widget.username,
      'Admin Panel Access',
      'Super admin accessed the dashboard',
    );
  }

  Future<void> _fetchSystemStats() async {
    setState(() => _isLoading = true);
    try {
      var schoolsSnapshot = await FirebaseFirestore.instance
          .collection('schools')
          .get();

      var activeSchools = await FirebaseFirestore.instance
          .collection('schools')
          .where('status', isEqualTo: 'active')
          .get();

      var usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      setState(() {
        _systemStats = {
          'totalSchools': schoolsSnapshot.size,
          'activeSchools': activeSchools.size,
          'totalUsers': usersSnapshot.size,
        };
        _isLoading = false;
      });

      // Log stats refresh
      await logActivity(
        widget.userId,
        username,
        'Stats Refresh',
        'System statistics updated',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching statistics: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  // Add this to your initState
  Future<void> _initializeSuperAdmin() async {
    setState(() => _isLoading = true);

    try {
      // Get current user
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      // Check if superadmin document exists
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        // Create superadmin document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set({
          'role': 'superadmin',
          'email': currentUser.email,
          'name': username,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'status': 'active'
        });

        setState(() {
          username = username;
          email = currentUser.email ?? '';
        });
      }

      // Log superadmin access
      await FirebaseFirestore.instance
          .collection('activity_log')
          .add({
        'action': 'Superadmin Access',
        'userId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'Superadmin account accessed system'
      });

    } catch (e) {
      debugPrint('Error initializing superadmin: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error initializing superadmin: $e'))
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  List<Widget> get _widgetOptions => <Widget>[
    DashboardScreen(
      userId: widget.userId,
      username: username,
      stats: _systemStats,
      isLoading: _isLoading,
    ),
    const NotificationsScreen(),
    const SchoolManagementScreen(),
    ProfileScreen(
      userId: widget.userId,
      username: username,
      email: email,
      userType: "superadmin",
      accentColor: Colors.blueAccent,
    ),
    FirestoreStructure(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
            'Super Admin Panel',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20)
        ),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSystemStats,
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: 'Schools',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storage),
            label: 'DB Structure',
          ),
        ],
        currentIndex: _selectedIndex,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey,
        onTap: _onItemSelected,
      ),
    );
  }

  void _onItemSelected(int index) async {
    setState(() {
      _selectedIndex = index;
    });

    // Log navigation
    String section = [
      'Dashboard',
      'Notifications',
      'Schools',
      'Profile',
      'DB Structure'
    ][index];

    await logActivity(
      widget.userId,
      username,
      'Navigation',
      'Accessed $section section',
    );
  }
}