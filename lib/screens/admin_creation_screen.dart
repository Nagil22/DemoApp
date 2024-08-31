import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminCreationScreen extends StatefulWidget {
  const AdminCreationScreen({super.key});

  @override
  AdminCreationScreenState createState() => AdminCreationScreenState();
}

class AdminCreationScreenState extends State<AdminCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  String _adminType = 'school';
  String _name = '';
  String _email = '';
  String _password = '';
  String _schoolId = '';
  List<DropdownMenuItem<String>> _schoolItems = [];

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    QuerySnapshot schoolSnapshot = await FirebaseFirestore.instance.collection('schools').get();
    setState(() {
      _schoolItems = schoolSnapshot.docs.map((doc) {
        return DropdownMenuItem(
          value: doc.id,
          child: Text(doc['name']),
        );
      }).toList();
    });
  }

  Future<void> _createAdmin() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        // Create user in Firebase Auth
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );

        // Create user document in root-level "users" collection
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'name': _name,
          'email': _email,
          'role': 'admin',
          'adminType': _adminType,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Create user document in school-specific "users" sub-collection
        if (_adminType == 'school') {
          await FirebaseFirestore.instance
              .collection('schools')
              .doc(_schoolId)
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
            'name': _name,
            'email': _email,
            'role': 'admin',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin created successfully!')),
        );

        // Clear the form after submission
        _formKey.currentState!.reset();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating admin: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Admin'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _adminType,
                decoration: const InputDecoration(labelText: 'Admin Type'),
                items: const [
                  DropdownMenuItem(value: 'school', child: Text('School Admin')),
                  DropdownMenuItem(value: 'company', child: Text('Company Admin')),
                  DropdownMenuItem(value: 'party', child: Text('Party Admin')),
                ],
                onChanged: (String? value) {
                  setState(() {
                    _adminType = value!;
                  });
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
                onSaved: (value) => _name = value!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) => value!.isEmpty ? 'Please enter an email' : null,
                onSaved: (value) => _email = value!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) => value!.length < 6 ? 'Password must be at least 6 characters' : null,
                onSaved: (value) => _password = value!,
              ),
              if (_adminType == 'school')
                DropdownButtonFormField<String>(
                  value: _schoolId,
                  decoration: const InputDecoration(labelText: 'School'),
                  items: _schoolItems,
                  validator: (value) => value == null ? 'Please select a school' : null,
                  onChanged: (String? value) {
                    setState(() {
                      _schoolId = value!;
                    });
                  },
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _createAdmin,
                child: const Text('Create Admin'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}