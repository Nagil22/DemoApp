import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/svg.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ResetPasswordScreenState createState() => ResetPasswordScreenState();
}

class ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _verifypasswordController = TextEditingController();

  bool _loading = false;
  bool _passwordNotShown = true;

  void _toggleVisibility() {
    setState(() {
      _passwordNotShown = !_passwordNotShown;
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _verifypasswordController.dispose();
    super.dispose();
  }

  void _sendEmail() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _loading = true;
      });
    }
    _dialogBuilder(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(
              "Reset Password",
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium!
                  .copyWith(fontWeight: FontWeight.w400)
          )
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                  margin: const EdgeInsets.symmetric(vertical: 20),
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
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical:5),
                  decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(29)
                  ),
                  child: TextFormField(
                    controller: _verifypasswordController,
                    decoration:  InputDecoration(
                        hintText: 'Verify Password',
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
                    obscureText:  _passwordNotShown,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  )
              ),
              ElevatedButton(
                onPressed: _sendEmail,
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
                const Text('Submit',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white)
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _dialogBuilder(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // title: const Text('Basic dialog title'),
          content:  SizedBox(
              height: 210.0,
              // width: 400.0,
              child:
              Column(children: [
                Container(
                  height: 80,
                  width: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical:20),
                  decoration:  BoxDecoration(
                      color:  Colors.grey.withOpacity(0.1),
                      borderRadius: const BorderRadius.all(Radius.circular(80))
                  ),
                  child: SvgPicture.asset(
                      'assets/illustrations/confetti.svg',
                      height:20
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Password Reset Successful!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 22
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You can now Login with your new Password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 16
                  ),
                ),
                const SizedBox(height: 16),
              ],
              )
          ),
          actions: <Widget>[
            TextButton(
              style: ElevatedButton.styleFrom(
                elevation: 4,
                minimumSize: const Size(350, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50.0),
                ),
                backgroundColor: Colors.blue,
              ),
              child: const Text('Login Now',  style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/login');
              },
            ),
          ],
        );
      },
    );
  }
}
