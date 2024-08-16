import 'package:demo/screens/profile/profile_menus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';


class AccountScreen extends StatefulWidget {
  final String userId;
  final String username;
  final String email;
  final String userType;

  const AccountScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.email,
    required this.userType,
  });

  @override
  AccountScreenState createState() => AccountScreenState();
}

class AccountScreenState extends State<AccountScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _email = widget.email;
  }

  void _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      User? user = _auth.currentUser;

      if (_email != widget.email) {
        await user!.verifyBeforeUpdateEmail(_email);
      }

      if (_password.isNotEmpty) {
        await user!.updatePassword(_password);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'email': _email});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    setState(() {
      _isUpdating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor:  HexColor.fromHex(profileBgColor)
      ),
      body: SingleChildScrollView(
        child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               Column(
                 children: [
                   Image.asset(
                       "assets/illustrations/profile.png",
                       height:170
                   ),
                   const SizedBox(height: 20),
                   Text(
                     'Hanif${widget.username}',
                     style: const TextStyle(fontSize: 24.0, fontWeight: FontWeight.w600),
                   ),
                   Text(
                     'hanif@app.com${widget.email}',
                     style: TextStyle(fontSize: 15.0, color: HexColor.fromHex(accentColor)),
                   ),
                 ],
              ),
              const SizedBox(height: 10),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 20),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical:5),
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10)
                ),
                child: TextFormField(
                  initialValue: _email,
                  decoration: const InputDecoration(
                      icon: Icon(
                        CupertinoIcons.mail,
                        color: Colors.grey,
                        size: 22.0,
                        semanticLabel: 'Text to announce in accessibility modes',
                      ),
                      hintText: 'Your email',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none
                  ),
                  onChanged: (value) {
                    _email = value;
                  },
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
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical:5),
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10)
                ),
                child: TextFormField(
                  decoration: const InputDecoration(
                      icon: Icon(
                        CupertinoIcons.phone,
                        color: Colors.grey,
                        size: 22.0,
                        semanticLabel: 'Text to announce in accessibility modes',
                      ),
                      hintText: 'Phone Number',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none
                  ),
                  onChanged: (value) {
                    // _password = value;
                  },
                  obscureText: true,
                  validator: (value) {
                    if (value != null && value.isNotEmpty && value.length < 6) {
                      return 'Enter Phone number';
                    }
                    return null;
                  },
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 20),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical:5),
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10)
                ),
                child: TextFormField(
                  decoration: const InputDecoration(
                      icon: Icon(
                        CupertinoIcons.padlock,
                        color: Colors.grey,
                        size: 22.0,
                        semanticLabel: 'Text to announce in accessibility modes',
                      ),
                      hintText: 'Gender',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      suffixIcon: Icon(
                        CupertinoIcons.chevron_down,
                        color: Colors.grey,
                        size: 22.0,
                        semanticLabel: 'Text to announce in accessibility modes',
                      ),
                  ),
                  onChanged: (value) {
                    // _password = value;
                  },
                  obscureText: true,
                  validator: (value) {
                    if (value != null && value.isNotEmpty && value.length < 6) {
                      return 'Enter Phone number';
                    }
                    return null;
                  },
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 20),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical:5),
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10)
                ),
                child: TextFormField(
                  decoration: const InputDecoration(
                      icon: Icon(
                        CupertinoIcons.padlock,
                        color: Colors.grey,
                        size: 22.0,
                        semanticLabel: 'Text to announce in accessibility modes',
                      ),
                      hintText: 'Password',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none
                  ),
                  onChanged: (value) {
                    _password = value;
                  },
                  obscureText: true,
                  validator: (value) {
                    if (value != null && value.isNotEmpty && value.length < 6) {
                      return 'Password should be at least 6 characters';
                    }
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateProfile,
                style: ElevatedButton.styleFrom(
                  elevation: 4,
                  minimumSize: const Size(350, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  backgroundColor: Colors.blue,
                ),
                child: _isUpdating ?
                LoadingAnimationWidget.fourRotatingDots(
                  color: Colors.white,
                  size: 40,
                )
                    :
                const Text('Save Changes',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white)
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}
