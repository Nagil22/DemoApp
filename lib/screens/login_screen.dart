import 'package:demo/admin_screen.dart';
import 'package:demo/school/admin_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

// Import the missing screen files
import 'package:demo/school/teacher_dashboard_screen.dart';
import 'package:demo/school/parent_dashboard_screen.dart';
import 'package:demo/school/student_dashboard_screen.dart';


class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Widget> handleAuthState(BuildContext context) async {
    User? user = _auth.currentUser;
    if (user == null) return const LoginScreen();

    try {
      DocumentSnapshot userData = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userData.exists) return const LoginScreen();

      Map<String, dynamic> data = userData.data() as Map<String, dynamic>;
      String role = data['role'] ?? '';
      String? schoolCode = data['schoolCode'];

      switch (role.toLowerCase()) {
        case 'superadmin':
          return AdminPanelScreen(
            userId: user.uid,
            username: data['name'] ?? '',
            email: user.email ?? '',
          );
        case 'schooladmin':
          if (schoolCode == null || schoolCode.isEmpty) return const LoginScreen();
          return AdminDashboardScreen(
            username: data['name'] ?? '',
            userId: user.uid,
            schoolCode: schoolCode,
            schoolName: data['schoolName'] ?? '',
            schoolType: data['schoolType'] ?? '',
          );
        case 'teacher':
          if (schoolCode == null || schoolCode.isEmpty) return const LoginScreen();
          return TeacherDashboardScreen(
            userId: user.uid,
            schoolCode: schoolCode,
            username: data['name'] ?? '',
            schoolName: data['schoolName'] ?? '',
            schoolType: data['schoolType'] ?? '',
          );
        case 'parent':
          if (schoolCode == null || schoolCode.isEmpty) return const LoginScreen();
          return ParentDashboardScreen(
            userId: user.uid,
            schoolCode: schoolCode,
            username: data['name'] ?? '',
            schoolName: data['schoolName'] ?? '',
          );
        case 'student':
          if (schoolCode == null || schoolCode.isEmpty) return const LoginScreen();
          return StudentDashboardScreen(
            userId: user.uid,
            schoolCode: schoolCode,
            username: data['name'] ?? '',
            schoolName: data['schoolName'] ?? '',
            schoolType: data['schoolType'] ?? '',
          );
        default:
          return const LoginScreen();
      }
    } catch (e) {
      debugPrint('Error in handleAuthState: $e');
      return const LoginScreen();
    }
  }

  Future<bool> createUser({
    required String email,
    required String password,
    required String name,
    required String role,
    String? schoolCode,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user == null) return false;

      await _firestore.collection('users').doc(user.uid).set({
        'name': name,
        'email': email,
        'role': role,
        'schoolCode': schoolCode,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      return true;
    } catch (e) {
      debugPrint('Error creating user: $e');
      return false;
    }
  }
}

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

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);

      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (!mounted) return;

        User? user = userCredential.user;
        if (user == null) throw Exception('Authentication failed');

        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          await FirebaseAuth.instance.signOut();
          throw Exception('User data not found');
        }

        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String role = userData['role'] ?? '';
        String schoolCode = userData['schoolCode'] ?? '';
        String schoolType = userData['schoolType'] ?? '';

        if (!mounted) return;

        Widget destinationScreen;
        switch (role) {
          case 'superadmin':
            destinationScreen = AdminPanelScreen(
              userId: user.uid,
              username: userData['name'] ?? '',
              email: user.email ?? '',
            );
            break;
          case 'schooladmin':
            destinationScreen = AdminDashboardScreen(
              username: userData['name'] ?? '',
              userId: user.uid,
              schoolCode: schoolCode,
              schoolName: userData['schoolName'] ?? '',
              schoolType: schoolType,
            );
            break;
          case 'teacher':
            destinationScreen = TeacherDashboardScreen(
              username: userData['name'] ?? '',
              userId: user.uid,
              schoolCode: schoolCode,
              schoolName: userData['schoolName'] ?? '',
              schoolType: schoolType,
            );
            break;
          case 'student':
            destinationScreen = StudentDashboardScreen(
              username: userData['name'] ?? '',
              userId: user.uid,
              schoolCode: schoolCode,
              schoolName: userData['schoolName'] ?? '',
              schoolType: schoolType,
            );
            break;
          case 'parent':
            destinationScreen = ParentDashboardScreen(
              username: userData['name'] ?? '',
              userId: user.uid,
              schoolCode: schoolCode,
              schoolName: userData['schoolName'] ?? '',
            );
            break;
          default:
            await FirebaseAuth.instance.signOut();
            throw Exception('Invalid user role');
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => destinationScreen),
        );
      } on FirebaseAuthException catch (e) {
        _handleAuthError(e);
      } catch (e) {
        _showError('Failed to sign in: $e');
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  void _handleAuthError(FirebaseAuthException e) {
    String message = 'An error occurred during sign in';
    switch (e.code) {
      case 'user-not-found':
        message = 'No user found for that email.';
        break;
      case 'wrong-password':
        message = 'Wrong password provided.';
        break;
      case 'user-disabled':
        message = 'This account has been disabled.';
        break;
      default:
        message = e.message ?? message;
    }
    _showError(message);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(29)
                  ),
                  child: TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                        hintText: 'Your Password',
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        suffixIcon: GestureDetector(
                          onTap: _toggleVisibility,
                          child: Icon(
                            _passwordNotShown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: Colors.grey,
                          ),
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
                onPressed: _loading ? null : _login,
                style: ElevatedButton.styleFrom(
                  elevation: 4,
                  minimumSize: const Size(350, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50.0),
                  ),
                  backgroundColor: Colors.blue,
                ),
                child: _loading
                    ? LoadingAnimationWidget.fourRotatingDots(
                  color: Colors.white,
                  size: 40,
                )
                    : const Text('LOGIN',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white)
                ),
              ),
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                        'Do not have an account?',
                        style: TextStyle(color: Colors.grey)),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/signup'),
                      child: const Text(
                          'Sign up',
                          style: TextStyle(color: Colors.blue)),
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}