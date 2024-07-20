import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  SignUpScreenState createState() => SignUpScreenState();
}

class SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  String _role = ''; // Role will be fetched from pending_users
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _verifyAndSignUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _loading = true;
      });

      try {
        // Verify username in pending_users
        QuerySnapshot pendingUserSnapshot = await FirebaseFirestore.instance
            .collection('pending_users')
            .where('username', isEqualTo: _usernameController.text.trim())
            .limit(1)
            .get();

        if (pendingUserSnapshot.docs.isNotEmpty) {
          DocumentSnapshot pendingUserDoc = pendingUserSnapshot.docs.first;
          Map<String, dynamic> pendingUserData = pendingUserDoc.data() as Map<String, dynamic>;

          _role = pendingUserData['role'];

          // Create Firebase Authentication user
          UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

          User? user = userCredential.user;
          if (user != null) {
            // Save user details to Firestore
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'username': _usernameController.text.trim(),
              'email': _emailController.text.trim(),
              'role': _role,
            });

            // Delete the pending user document
            await FirebaseFirestore.instance.collection('pending_users').doc(pendingUserDoc.id).delete();

            // Navigate to appropriate dashboard
            switch (_role) {
              case 'School':
                Navigator.pushReplacementNamed(
                  context,
                  '/school-dashboard',
                  arguments: {
                    'username': _usernameController.text.trim(),
                    'userId': user.uid,
                  },
                );
                break;
              case 'Company':
                Navigator.pushReplacementNamed(
                  context,
                  '/company-dashboard',
                  arguments: {
                    'username': _usernameController.text.trim(),
                    'userId': user.uid,
                  },
                );
                break;
              case 'Party':
                Navigator.pushReplacementNamed(
                  context,
                  '/party-dashboard',
                  arguments: {
                    'username': _usernameController.text.trim(),
                    'userId': user.uid,
                  },
                );
                break;
              default:
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid role specified.')),
                );
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username not found in pending users.')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign up: $e')),
        );
      } finally {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Text("Create an account",
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium!
                      .copyWith(fontWeight: FontWeight.w700)
              ),
              const Spacer(),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 20),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical:5),
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(29)
                ),
                child:
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                          hintText: 'Username',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your username';
                        }
                        return null;
                      },
                    )
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 20),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical:5),
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(29)
                ),
                child:
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                          hintText: 'Email',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        return null;
                      },
                    )
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 20),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical:5),
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(29)
                ),
                child:
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                          hintText: 'Password',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    )
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _verifyAndSignUp,
                style: ElevatedButton.styleFrom(
                  elevation: 4,
                  minimumSize: const Size(350, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50.0),
                  ),
                  backgroundColor: Colors.blue,
                ),
                child: _loading ?
                LoadingAnimationWidget.fourRotatingDots(
                  color: Colors.white,
                  size: 50,
                )
                    :
                const Text('COMPLETE REGISTRATION',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white)
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
