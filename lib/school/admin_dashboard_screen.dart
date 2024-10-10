import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import '../screens/profile_screen.dart';
import '../dash_screens/payments_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String username;
  final String userId;
  final String schoolCode;
  final String schoolName;

  const AdminDashboardScreen({
    super.key,
    required this.username,
    required this.userId,
    required this.schoolCode,
    required this.schoolName,
  });

  @override
  AdminDashboardScreenState createState() => AdminDashboardScreenState();
}

List<IconData> navIcons = [
  Icons.dashboard,
  Icons.people,
  Icons.payment,
  Icons.person,
];
List<String> navTitle = [
  "Overview",
  "Users",
  "Payment",
  "Profile"
];

class AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  int _selectedIndex = 0;
  String _schoolName = '';
  String _schoolAddress = '';
  String _logoUrl = '';
  Color _colorPrimary = Colors.blue;
  Color _colorSecondary = Colors.blueAccent;
  Color _teacherColor = Colors.green;
  Color _studentColor = Colors.orange;
  Color _parentColor = Colors.purple;
  final TextEditingController _searchController = TextEditingController();
  List<QueryDocumentSnapshot> _filteredUsers = [];
  bool _isLoading = true;
  bool _hasUnsavedChanges = false;
  Map<String, dynamic> _originalSchoolData = {};
  Map<String, dynamic> _updatedSchoolData = {};
  bool _schoolExists = false;

  late Stream<QuerySnapshot> usersStream;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // Initialize the stream
    usersStream = FirebaseFirestore.instance
        .collection('users')
        .where('schoolCode', isEqualTo: widget.schoolCode)
        .orderBy('name')
        .snapshots();

    // Fetch school configuration
    await _fetchSchoolConfiguration();
  }

  Future<void> _fetchSchoolConfiguration() async {
    try {
      if (kDebugMode) {
        print('Fetching school configuration for school code: ${widget
            .schoolCode}');
      }
      final schoolQuery = await _firestore
          .collection('schools')
          .where('code', isEqualTo: widget.schoolCode)
          .limit(1)
          .get();

      if (schoolQuery.docs.isNotEmpty) {
        final schoolDoc = schoolQuery.docs.first;
        final schoolConfig = schoolDoc.data();

        if (kDebugMode) {
          print('School found: ${schoolConfig['name']}');
        }

        setState(() {
          _schoolExists = true;
          _originalSchoolData = Map<String, dynamic>.from(schoolConfig);
          _updatedSchoolData = Map<String, dynamic>.from(schoolConfig);
          _schoolName = schoolConfig['name'] ?? '';
          _schoolAddress = schoolConfig['address'] ?? '';
          _logoUrl = schoolConfig['logo'] ?? '';
          _colorPrimary = Color(int.parse(
              schoolConfig['accentColor']?.replaceFirst('#', '0xff') ??
                  '0xFF2196F3'));
          _colorSecondary = Color(int.parse(
              schoolConfig['accentColor']?.replaceFirst('#', '0xff') ??
                  '0xFF64B5F6')).withOpacity(0.7);
          _teacherColor = Color(int.parse(
              schoolConfig['teacherColor']?.replaceFirst('#', '0xff') ??
                  '0xFF4CAF50'));
          _studentColor = Color(int.parse(
              schoolConfig['studentColor']?.replaceFirst('#', '0xff') ??
                  '0xFFFFA726'));
          _parentColor = Color(int.parse(
              schoolConfig['parentColor']?.replaceFirst('#', '0xff') ??
                  '0xFF9C27B0'));
          _isLoading = false;
        });
      } else {
        if (kDebugMode) {
          print('School not found for code: ${widget.schoolCode}');
        }
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching school configuration: $e');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_schoolExists) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create School')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('School "${widget.schoolCode}" does not exist.'),
            ],
          ),
        ),
      );
    }

    return Theme(
      data: ThemeData(
        primaryColor: _colorPrimary,
        colorScheme: ColorScheme.fromSwatch().copyWith(
            secondary: _colorSecondary),
      ),
      child: Scaffold(
        appBar: AppBar(
          title:
          Text(
              'Admin Dashboard - $_schoolName',
              style: const TextStyle(
                 fontWeight: FontWeight.w500,
                  fontSize: 20
              )
          ),
          // backgroundColor: _colorPrimary,
          leading: Container(
            padding: const EdgeInsets.all(8.0),
            child: _logoUrl.isNotEmpty
                ? Image.network(_logoUrl, fit: BoxFit.contain)
                : const Placeholder(
              fallbackHeight: 40,
              fallbackWidth: 40,
              color: Colors.white,
            ),
          ),
          actions: [
            if (_hasUnsavedChanges)
              TextButton(
                onPressed: _saveChanges,
                child: Text(
                    'Save Changes', style: TextStyle(color: _colorSecondary)),
              ),
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.black),
              onPressed: () {
                // Implement notification viewing functionality
              },
            ),
          ],
        ),
        body: Stack(
            children: [
              _buildBody(),
              Align(alignment: Alignment.bottomCenter, child: _navBar())
            ],
          ),
        ),
      );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildOverviewPage();
      case 1:
        return _buildUsersPage();
      case 2:
        return PaymentsScreen(schoolCode: widget.schoolCode, userId: '',);
      case 3:
        return ProfileScreen(userId: widget.userId,
          username: '',
          email: '',
          userType: '',
          accentColor: Colors.blueAccent,);
      default:
        return const Center(child: Text('Page not found'));
    }
  }

  Widget _navBar(){
    return Container(
      height: 65,
      margin: const EdgeInsets.only(
        right: 24,
        left: 24,
        bottom: 24
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 20,
            spreadRadius: 10
          )
        ]
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: navIcons.map((icon) {
          int index = navIcons.indexOf(icon);
          bool isSelected = _selectedIndex == index;
          return Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: (){
                setState(() {
                  _selectedIndex = index;
                });
              },
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(
                          top: 15,
                          bottom:0,
                          left: 30,
                          right: 30
                      ),
                      child: Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
                      ),
                    Text(
                      navTitle[index],
                      style: TextStyle(
                          color: isSelected ? Colors.blue : Colors.grey,
                          fontSize: 10
                      )
                    ),
                    const SizedBox(height: 15)
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      )
    );
  }

  Widget _buildOverviewPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('School Details', style: Theme
              .of(context)
              .textTheme
              .headlineSmall),
          const SizedBox(height: 16),
          _buildEditableField('School Name', _schoolName, (value) =>
              _updateSchoolField('name', value)),
          _buildEditableField('School Address', _schoolAddress, (value) =>
              _updateSchoolField('address', value)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _pickSchoolLogo,
            style: ElevatedButton.styleFrom(
            elevation: 1,
            minimumSize: const Size(400, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50.0),
            ),
            backgroundColor: Colors.white,
          ),
            child: const Text('Update School Logo',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blue)),
          ),
          const SizedBox(height: 16),
          Text('User Accent Colors', style: Theme
              .of(context)
              .textTheme
              .titleLarge),
          const SizedBox(height: 8),
          _buildColorPicker('Teacher Accent', _teacherColor, (color) =>
              _updateSchoolField('teacherAccent',
                  '#${color.value.toRadixString(16).substring(2)}')),
          _buildColorPicker('Student Accent', _studentColor, (color) =>
              _updateSchoolField('studentAccent',
                  '#${color.value.toRadixString(16).substring(2)}')),
          _buildColorPicker('Parent Accent', _parentColor, (color) =>
              _updateSchoolField('parentAccent',
                  '#${color.value.toRadixString(16).substring(2)}')),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saveChanges,style: ElevatedButton.styleFrom(
            elevation: 4,
            minimumSize: const Size(400, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50.0),
            ),
            backgroundColor: Colors.blue,
          ),
            child: const Text('Save Changes',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(String label, String value,
      Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        onChanged: (newValue) {
          onChanged(newValue);
          _checkForUnsavedChanges();
        },
      ),
    );
  }

  Widget _buildColorPicker(String label, Color currentColor,
      Function(Color) onColorChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Text(label),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => _showColorPicker(label, currentColor, onColorChanged),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: currentColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(String label, Color currentColor,
      Function(Color) onColorChanged) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Pick $label color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (color) {
                currentColor = color;
              },
              pickerAreaHeightPercent: 0.8,
              labelTypes: const [],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                onColorChanged(currentColor);
                _updateSchoolField('${label.toLowerCase()}Color',
                    '#${currentColor.value.toRadixString(16).substring(2)}');
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label color updated')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickSchoolLogo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      try {
        final ref = _storage.ref().child('school_logos/${widget.schoolCode}');
        await ref.putFile(File(image.path));
        final url = await ref.getDownloadURL();
        _updateSchoolField('logo', url);
        setState(() {
          _logoUrl = url;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating logo: $e')));
      }
    }
  }

  void _updateSchoolField(String field, dynamic value) {
    setState(() {
      _updatedSchoolData[field] = value;
    });
    _checkForUnsavedChanges();

    // Update Firestore immediately for color changes
    if (field.endsWith('Color')) {
      _firestore.collection('schools').doc(widget.schoolCode).update(
          {field: value}).then((_) {
        if (kDebugMode) {
          print('Updated $field to $value in Firestore');
        }
      }).catchError((error) {
        if (kDebugMode) {
          print('Error updating $field: $error');
        }
      });
    }
  }



  void _checkForUnsavedChanges() {
    bool hasChanges = false;
    _originalSchoolData.forEach((key, value) {
      if (_updatedSchoolData[key] != value) {
        hasChanges = true;
      }
    });
    setState(() {
      _hasUnsavedChanges = hasChanges;
    });
  }

  Future<void> _saveChanges() async {
    try {
      final schoolQuery = await _firestore
          .collection('schools')
          .where('code', isEqualTo: widget.schoolCode)
          .limit(1)
          .get();

      if (schoolQuery.docs.isNotEmpty) {
        final schoolDoc = schoolQuery.docs.first;
        await schoolDoc.reference.update(_updatedSchoolData);
        setState(() {
          _originalSchoolData = Map<String, dynamic>.from(_updatedSchoolData);
          _hasUnsavedChanges = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Changes saved successfully')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: School not found')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving changes: $e')));
      }
    }
  }

  Widget _buildUsersPage() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: TextField(
            controller: _searchController,
            decoration:  InputDecoration(
              hintText: 'Search users',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(onPressed: _searchController.clear, icon: const Icon(Icons.clear)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                borderSide: const BorderSide(width:  0.2)
              )
            ),
            onChanged: _filterUsers,),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: usersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No users found'));
              }

              _filteredUsers = snapshot.data!.docs;
              return ListView.builder(
                itemCount: _filteredUsers.length,
                itemBuilder: (context, index) {
                  final doc = _filteredUsers[index];
                  final user = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getUserColor(user['role']),
                      child: Text(user['name'][0].toUpperCase()),
                    ),
                    title: Text(user['name'] ?? 'No name',  style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user['email'] ?? 'No email'),
                        Text('Role: ${user['role'] ?? 'No role'}'),
                      ],
                    ),
                    trailing: Switch(
                      value: user['status'] == 'active',
                      onChanged: (bool value) {
                        _updateUserStatus(doc.id, value ? 'active' : 'inactive');
                      },
                    ),
                    onTap: () => _showUserDetailsDialog(doc),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(26.0),
          child:  ElevatedButton(
            onPressed: _showCreateUserDialog,
            style: ElevatedButton.styleFrom(
            elevation: 4,
            minimumSize: const Size(300, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50.0),
            ),
            backgroundColor: Colors.blue,
          ),
            child: const Text('Create New User',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Color _getUserColor(String? role) {
    switch (role) {
      case 'teacher':
        return _teacherColor;
      case 'student':
        return _studentColor;
      case 'parent':
        return _parentColor;
      case 'schooladmin':
        return _colorPrimary;
      default:
        return Colors.grey;
    }
  }

  void _updateUserStatus(String userId, String status) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'status': status})
        .then((_) => print('User status updated'))
        .catchError((error) => print('Failed to update user status: $error'));
  }
  void _showCreateUserDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    String selectedRole = 'student';
    String selectedStatus = 'active';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create New User'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      selectedRole = newValue;
                    }
                  },
                  items: <String>['student', 'teacher', 'parent', 'schooladmin']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      selectedStatus = newValue;
                    }
                  },
                  items: <String>['active', 'inactive', 'suspended']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Create'),
              onPressed: () {
                _createUser(
                  nameController.text,
                  emailController.text,
                  passwordController.text,
                  selectedRole,
                  selectedStatus,
                );
              },
            ),
          ],
        );
      },
    );
  }
  

  void _filterUsers(String query) {
    final filtered = _filteredUsers.where((userDoc) {
      final user = userDoc.data() as Map<String, dynamic>;
      return user['name'].toLowerCase().contains(query.toLowerCase()) ||
          user['email'].toLowerCase().contains(query.toLowerCase());
    }).toList();

    setState(() {
      _filteredUsers = filtered;
    });
  }

  void _showUserDetailsDialog(QueryDocumentSnapshot userDoc) {
    final user = userDoc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(user['name']),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Email: ${user['email']}'),
                Text('Role: ${user['role']}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => _toggleUserAccess(userDoc),
                child: Text(user['blocked'] == true ? 'Unblock' : 'Block'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _toggleUserAccess(QueryDocumentSnapshot userDoc) {
    final user = userDoc.data() as Map<String, dynamic>;
    final isBlocked = user['blocked'] == true;
    _firestore.collection('schools').doc(widget.schoolCode).collection('users')
        .doc(userDoc.id).update({
      'blocked': !isBlocked,
    })
        .then((_) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isBlocked ? 'User unblocked' : 'User blocked'),
      ));
    });
  }

  Future<void> _createUser(String name, String email, String password, String role, String status) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Create user in Firebase Authentication
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'role': role,
        'schoolCode': widget.schoolCode,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });

      // Wait for a short time to ensure the new user is reflected in the stream
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('User created successfully'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to create user: $e'),
        ));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

