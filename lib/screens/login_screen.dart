import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

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

  bool _passwordNotShown = true;

  void _toggleVisibility() {
    setState(() {
      _passwordNotShown = !_passwordNotShown;
    });
  }

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
            switch (userType) {
              case 'SuperAdmin':
                Navigator.pushReplacementNamed(
                  context,
                  '/admin-panel',
                  arguments: {
                    'username': userDoc.data()!['username'],
                    'userId': user.uid,
                    'schoolId': userDoc.data()!['schoolId'],
                  },
                );
                break;
              case 'School':
                Navigator.pushReplacementNamed(
                  context,
                  '/school-dashboard',
                  arguments: {
                    'username': userDoc.data()!['username'],
                    'userId': user.uid,
                  },
                );
                break;
              case 'Company':
                Navigator.pushReplacementNamed(
                  context,
                  '/company-dashboard',
                  arguments: {
                    'username': userDoc.data()!['username'],
                    'userId': user.uid,
                  },
                );
                break;
              case 'Party':
                Navigator.pushReplacementNamed(
                  context,
                  '/party-dashboard',
                  arguments: {
                    'username': userDoc.data()!['username'],
                    'userId': user.uid,
                  },
                );
                break;
              case 'Student':
                Navigator.pushReplacementNamed(
                  context,
                  '/student-dashboard',
                  arguments: {
                    'username': userDoc.data()!['username'],
                    'userId': user.uid,
                  },
                );
                break;
              case 'Teacher':
                Navigator.pushReplacementNamed(
                  context,
                  '/teacher-dashboard',
                  arguments: {
                    'username': userDoc.data()!['username'],
                    'userId': user.uid,
                  },
                );
                break;
              case 'Parent':
                Navigator.pushReplacementNamed(
                  context,
                  '/parent-dashboard',
                  arguments: {
                    'username': userDoc.data()!['username'],
                    'userId': user.uid,
                  },
                );
                break;
              default:
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
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Text("Welcome Back 👋🏽",
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium!
                      .copyWith(fontWeight: FontWeight.w700)
              ),
              const Text("Login to your account",
                  style: TextStyle(fontWeight: FontWeight.normal)
              ),
              const SizedBox(height: 30),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 20),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical:5),
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(29)
                ),
                child: TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                      hintText: 'Your email',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                ),
              ),
              Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical:5),
                  decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(29)
                  ),
                  child: TextFormField(
                    controller: _passwordController,
                    decoration:  InputDecoration(
                        hintText: 'Your Password',
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        suffixIcon: GestureDetector(
                          onTap: _toggleVisibility,
                          child: _passwordNotShown ?
                          const Icon(Icons.visibility_off_outlined, color: Colors.grey)
                              :
                          const Icon(Icons.visibility_outlined, color: Colors.grey),
                        )
                    ),
                    obscureText: _passwordNotShown,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  )
              ),
              Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Spacer(),
                      TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/forgot'),
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(color: Colors.blue),
                          )
                      ),
                    ],
                  )
              ),
              ElevatedButton(
                onPressed: _login,
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
                  size: 40,
                )
                    :
                const Text('LOGIN',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white)
                ),
              ),
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      child: const Text(
                          'Do not have an account?',
                          style: TextStyle(color: Colors.grey)),
                    ),
                    GestureDetector(
                      onTap: (){},
                      child: TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/signup'),
                        child: const Text(
                            'Sign up',
                            style: TextStyle(color: Colors.blue)),
                      ),
                    )
                  ]
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
