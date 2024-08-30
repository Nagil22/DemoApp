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
import 'package:demo/screens/company_dashboard_screen.dart';
import 'package:demo/screens/party_dashboard_screen.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Widget> handleAuthState(BuildContext context, String? username, String? userId) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userData = await _firestore.collection('users').doc(user.uid).get();

        if (userData.exists) {
          Map<String, dynamic> data = userData.data() as Map<String, dynamic>;
          String role = data['role'] ?? '';
          String? schoolId = data.containsKey('schoolId') ? data['schoolId'] : null;

          print('User role: $role'); // Debugging line

          switch (role.toLowerCase()) {
            case 'superadmin':
              return AdminPanelScreen(
                userId: user.uid,
                username: data['name'] ?? '',
                email: user.email ?? '',
              );
            case 'admin':
              return AdminDashboardScreen(
                username: data['name'] ?? '',
                userId: user.uid,
                schoolId: schoolId ?? '',
                schoolName: '',
              );
            case 'teacher':
              return TeacherDashboardScreen(
                userId: user.uid,
                schoolId: schoolId ?? '',
                username: data['name'] ?? '',
                schoolName: '',
              );
            case 'parent':
              return ParentDashboardScreen(
                userId: user.uid,
                schoolId: schoolId ?? '',
                username: data['name'] ?? '',
                schoolName: '',
              );
            case 'student':
              return StudentDashboardScreen(
                userId: user.uid,
                schoolId: schoolId ?? '',
                username: data['name'] ?? '',
                schoolName: '',
              );
            case 'company-admin':
              return CompanyDashboardScreen(
                username: username ?? '',
                userId: userId ?? '',
              );
            case 'party-admin':
              return PoliticalPartyDashboardScreen(
                username: username ?? '',
                userId: userId ?? '',
              );
            default:
              print('Unknown role: $role'); // Debugging line
              return const LoginScreen();
          }
        } else {
          print('User document does not exist'); // Debugging line
          return const LoginScreen();
        }
      } catch (e) {
        print('Error in handleAuthState: $e'); // Debugging line
        return const LoginScreen();
      }
    }
    print('User is null'); // Debugging line
    return const LoginScreen();
  }

  Future<void> createUser({
    required String email,
    required String password,
    required String name,
    required String role,
    String? schoolId,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'name': name,
          'email': email,
          'role': role,
          'schoolId': schoolId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print(e.toString());
      // Handle error (show error message to user)
    }
  }
}

extension on Object? {
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

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _loading = true;
      });

      try {
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        User? user = userCredential.user;
        if (user != null) {
          AuthService authService = AuthService();
          Widget destinationScreen = await authService.handleAuthState(
              context,
              user.displayName,
              user.uid
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => destinationScreen),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to sign in: User is null')),
          );
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage = 'An error occurred during sign in';
        if (e.code == 'user-not-found') {
          errorMessage = 'No user found for that email.';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'Wrong password provided for that user.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
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
                onPressed: _login,
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