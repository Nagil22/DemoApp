import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _loading = true;
      });

      try {
        // Authenticate with Firebase Auth
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        User? user = userCredential.user;
        if (user != null) {
          // Fetch the user role from Firestore using uid as document ID
          DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (userDoc.exists && userDoc.data()!.containsKey('role')) {
            String userType = userDoc.data()!['role'];

            // Navigate based on userType
            if (userType == 'Admin') {
              Navigator.pushReplacementNamed(
                context,
                '/admin-panel',
                arguments: {
                  'username': userDoc.data()!['username'],
                  'userId': user.uid,
                },
              );
            } else if (userType == 'School') {
              Navigator.pushReplacementNamed(
                context,
                '/school-dashboard',
                arguments: {
                  'username': userDoc.data()!['username'],
                  'userId': user.uid,
                },
              );
            } else if (userType == 'Company') {
              Navigator.pushReplacementNamed(
                context,
                '/company-dashboard',
                arguments: {
                  'username': userDoc.data()!['username'],
                  'userId': user.uid,
                },
              );
            } else if (userType == 'Party') {
              Navigator.pushReplacementNamed(
                context,
                '/party-dashboard',
                arguments: {
                  'username': userDoc.data()!['username'],
                  'userId': user.uid,
                },
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invalid role specified.')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to fetch user role.')),
            );
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign in: $e')),
        );
      } finally {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _login,
                child: _loading ? const CircularProgressIndicator() : const Text('Login'),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/signup'),
                child: const Text('Sign up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
