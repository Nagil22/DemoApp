import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/svg.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ForgotPasswordScreenState createState() => ForgotPasswordScreenState();
}

class ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _loading = false;


  @override
  void dispose() {
    _emailController.dispose();
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
              "Forgot Password",
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
                  child:
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                        hintText: 'Your email address',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
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
                            'assets/illustrations/mailbox.svg',
                            height:20
                        ),
                      ),
                       const SizedBox(height: 16),
                       const Text("Check Your Email!",
                           textAlign: TextAlign.center,
                           style: TextStyle(
                               fontWeight: FontWeight.w400,
                               fontSize: 22
                           ),
                       ),
                       const SizedBox(height: 16),
                       const Text(
                          'We\'ve sent a password reset link to your email.It is valid for 24 hours',
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
          child: const Text('Check Email',  style: TextStyle(color: Colors.white)),
          onPressed: () {
          Navigator.of(context).pop();
          Navigator.pushNamed(context, '/reset');
          // setState(() {
          //   _loading = false;
          // });
          },
          ),
        ],
        );
      },
    );
}
}
