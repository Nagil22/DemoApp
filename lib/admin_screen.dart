import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/school/admin_dashboard_screen.dart';
import 'package:demo/school/parent_dashboard_screen.dart';
import 'package:demo/school/student_dashboard_screen.dart';
import 'package:demo/school/teacher_dashboard_screen.dart';
import 'package:demo/screens/company_dashboard_screen.dart';
import 'package:demo/screens/party_dashboard_screen.dart';
import 'package:demo/screens/school_dashboard_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  AdminPanelScreenState createState() => AdminPanelScreenState();
}

class AdminPanelScreenState extends State<AdminPanelScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    NotificationsScreen(),
    AnalyticsScreen(),
    SchoolManagementScreen(),
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
        title: const Text('Super Admin Panel'),
        backgroundColor: Colors.black,
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: 'Schools',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ready to work',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickAccessCard(
                  context,
                  icon: Icons.school,
                  title: 'Schools',
                  onTap: () => _navigateToDashboard(context, const SchoolDashboardScreen(username: '', userId: '')),
                ),
                _buildQuickAccessCard(
                  context,
                  icon: Icons.business,
                  title: 'Companies',
                  onTap: () => _navigateToDashboard(context, const CompanyDashboardScreen(username: '', userId: '')),
                ),
                _buildQuickAccessCard(
                  context,
                  icon: Icons.people,
                  title: 'Parents',
                  onTap: () => _navigateToDashboard(context, const ParentDashboardScreen(username: '', userId: '')),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickAccessCard(
                  context,
                  icon: Icons.admin_panel_settings,
                  title: 'School Admin',
                  onTap: () => _navigateToDashboard(context, const AdminDashboardScreen(username: '', userId: '', schoolId: '')),
                ),
                _buildQuickAccessCard(
                  context,
                  icon: Icons.gavel,
                  title: 'Party',
                  onTap: () => _navigateToDashboard(context, const PoliticalPartyDashboardScreen(username: '', userId: '')),
                ),
                _buildQuickAccessCard(
                  context,
                  icon: Icons.analytics,
                  title: 'Analytics',
                  onTap: () {
                    // Navigate to analytics dashboard
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),
            Text(
              'Latest activity',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 10),
            _buildActivityList(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard(BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, size: 40),
              const SizedBox(height: 8),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('activity_log').orderBy('timestamp', descending: true).limit(5).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var activities = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            var activity = activities[index];
            return ListTile(
              leading: CircleAvatar(
                child: Text(activity['user'][0]),
              ),
              title: Text(activity['action']),
              subtitle: Text(activity['timestamp'].toDate().toString()),
            );
          },
        );
      },
    );
  }

  void _navigateToDashboard(BuildContext context, Widget dashboard) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => dashboard),
    );
  }
}

// You'll need to implement these new screens:
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Implement analytics screen
    return const Center(child: Text('Analytics Screen'));
  }
}

class SchoolManagementScreen extends StatelessWidget {
  const SchoolManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Implement school management screen
    return const Center(child: Text('School Management Screen'));
  }
}

// Modify the NotificationsScreen to fit super admin needs
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Implement super admin notification screen
    return const Center(child: Text('Super Admin Notifications'));
  }
}