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
      ///// appBar: AppBar(title: const Text('Login')),
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
              // SvgPicture.asset(
              //     "assets/illustrations/login.svg",
              //     height: size.height * 0.2
              // ),
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
                      // icon: Icon(Icons.person, color: ,),
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
                margin: const EdgeInsets.symmetric(vertical: 20),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical:5),
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(29)
                ),
              child: TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                          hintText: 'Your Password',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          suffixIcon: Icon(Icons.visibility_off_outlined, color: Colors.grey,)),
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
                      size: 50,
                    )
                        :
                    const Text('LOGIN',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white)
                    ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/signup'),
                child: const Text(
                    'Do not have an account? Sign up',
                    style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
