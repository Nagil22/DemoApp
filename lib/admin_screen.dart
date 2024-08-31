import 'package:demo/dash_screens/school_management_screen.dart';
import 'package:demo/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/school/admin_dashboard_screen.dart';
import 'package:demo/school/parent_dashboard_screen.dart';
import 'package:demo/screens/company_dashboard_screen.dart';
import 'package:demo/screens/party_dashboard_screen.dart';
import 'package:demo/screens/school_dashboard_screen.dart';

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

class AdminPanelScreenState extends State<AdminPanelScreen> {
  int _selectedIndex = 0;
  late String username;
  late String email;

  @override
  void initState() {
    super.initState();
    username = widget.username;
    email = widget.email;
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    setState(() {
      username = userDoc['username'];
      email = userDoc['email'];
    });
  }

  List<Widget> get _widgetOptions => <Widget>[
    const DashboardScreen(userId: '',),
    const NotificationsScreen(),
    const AnalyticsScreen(),
    const AdminCreationScreen(),
    ProfileScreen(
        userId: widget.userId,
        username: username,
        email: email,
        userType: "Super Admin"),
    const AdminManagementScreen(), // Integrating the AdminManagementScreen here
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
        centerTitle: true,
        title: const Text('Super admin panel', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20)),
        backgroundColor: Colors.white,
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
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings),
            label: 'Admin Management',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Profile',
          ),

        ],
        currentIndex: _selectedIndex,
        backgroundColor: Colors.blue,
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required String userId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: _buildQuickAccessCard(
                    context,
                    icon: Icons.school,
                    title: 'Schools',
                    onTap: () => _navigateToDashboard(context,
                        const SchoolDashboardScreen(username: '', userId: '', schoolName: '', schoolId: '',)),
                  ),
                ),
                Expanded(
                  child: _buildQuickAccessCard(
                    context,
                    icon: Icons.business,
                    title: 'Companies',
                    onTap: () => _navigateToDashboard(context,
                        const CompanyDashboardScreen(username: '', userId: '')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: _buildQuickAccessCard(
                    context,
                    icon: Icons.people,
                    title: 'Parents',
                    onTap: () => _navigateToDashboard(context,
                        const ParentDashboardScreen(username: '', userId: '', schoolId: '', schoolName: '',)),
                  ),
                ),
                Expanded(
                  child: _buildQuickAccessCard(
                    context,
                    icon: Icons.admin_panel_settings,
                    title: 'School Admin',
                    onTap: () => _navigateToDashboard(
                        context,
                        const AdminDashboardScreen(
                          username: '', userId: '', schoolId: '', schoolName: '',)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: _buildQuickAccessCard(
                    context,
                    icon: Icons.gavel,
                    title: 'Party',
                    onTap: () => _navigateToDashboard(
                        context,
                        const PoliticalPartyDashboardScreen(
                            username: '', userId: '')),
                  ),
                ),
                Expanded(
                  child: _buildQuickAccessCard(
                    context,
                    icon: Icons.analytics,
                    title: 'Analytics',
                    onTap: () {
                      // Navigate to analytics dashboard
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),
            Text(
              'Latest activity',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            _buildActivityList(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 7,
        color: Colors.blue,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(
                icon,
                size: 40,
                color: Colors.white,
              ),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(fontSize: 18, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('activity_log')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 100),
              Icon(Icons.no_accounts_outlined, size: 40, color: Colors.grey),
              SizedBox(width: 20),
              Text(
                'No activity to show now',
                style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey),
              ),
            ],
          );
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

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Analytics',
            style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: const Center(
        child: Text('Analytics Screen'),
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications',
            style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: const Center(
        child: Text('Super Admin Notifications'),
      ),
    );
  }
}

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  AdminManagementScreenState createState() => AdminManagementScreenState();
}

class AdminManagementScreenState extends State<AdminManagementScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _role = 'Super Admin'; // Default role is Super Admin
  String _schoolId = ''; // Default is empty for Super Admins

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Management',
            style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<String>(
              value: _role,
              onChanged: (String? newRole) {
                setState(() {
                  _role = newRole!;
                  _schoolId = ''; // Reset schoolId when role changes
                });
              },
              items: <String>[
                'Super Admin',
                'School Admin',
                'Company Admin',
                'Party Admin'
              ].map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            if (_role == 'School Admin')
              TextField(
                controller: TextEditingController(text: _schoolId),
                decoration: const InputDecoration(
                  labelText: 'School ID',
                ),
                onChanged: (value) {
                  setState(() {
                    _schoolId = value;
                  });
                },
              ),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _createAdmin();
              },
              child: const Text('Create Admin'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAdmin() async {
    try {
      DocumentReference userRef = await FirebaseFirestore.instance
          .collection('users')
          .add({
        'username': _usernameController.text,
        'email': _emailController.text,
        'role': _role,
        if (_role == 'School Admin') 'schoolId': _schoolId,
      });

      if (_role == 'School Admin') {
        await FirebaseFirestore.instance
            .collection('schools')
            .doc(_schoolId)
            .collection('admins')
            .doc(userRef.id)
            .set({
          'username': _usernameController.text,
          'email': _emailController.text,
        });
      }
    } catch (error) {
      // Handle error
    }
  }
}
