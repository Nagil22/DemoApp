import 'package:demo/screens/profile/profile_menus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:hexcolor/hexcolor.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final String username;
  final String email;
  final String userType;

  const ProfileScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.email,
    required this.userType,
  });

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
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
        backgroundColor:  Colors.transparent
      ),
      backgroundColor: HexColor(profileBgColor),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child:  Column(
            children: [
               SizedBox(
                width: 400,
                height: 160,
                child:  DecoratedBox(
                  decoration:  BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  ),
                  child:  Column (
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                            children: [
                              const SizedBox(width: 20),
                              const CircleAvatar(
                                radius: 25,
                                backgroundColor: Colors.black,
                                child: Icon(Icons.person, size: 25, color: Colors.white),
                              ),
                              const SizedBox(width: 20),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'John Doe ${widget.username}',
                                    style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600,),
                                    textAlign: TextAlign.left,
                                  ),
                                  Text(
                                    'hanif@app.com ${widget.email}',
                                    style: TextStyle(fontSize: 13.0, color: HexColor(accentColor)),
                                    textAlign: TextAlign.left,
                                  ),
                                ],
                              ),
                              const Spacer(),
                            ],
                        ),
                       const SizedBox(height: 20),
                       SizedBox(
                         width: 400,
                         height: 80,
                         child:  DecoratedBox(
                             decoration:  BoxDecoration(
                               color: Colors.blue,
                               borderRadius: BorderRadius.circular(20),
                             ),
                             child: const Column(
                               mainAxisAlignment: MainAxisAlignment.center,
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Row(
                                   // mainAxisAlignment: MainAxisAlignment.center,
                                   children: [
                                     SizedBox(width: 20),
                                     Icon(
                                       CupertinoIcons.building_2_fill,
                                       color: Colors.white,
                                       size: 20.0,
                                       semanticLabel: 'Text to announce in accessibility modes',
                                     ),
                                     SizedBox(width: 20),
                                     Text(
                                       'Year 12 at Example Academy',
                                       style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Colors.white),
                                     ),
                                     Spacer(),
                                     Icon(
                                       CupertinoIcons.chevron_forward,
                                       color: Colors.white,
                                       size: 18.0,
                                       semanticLabel: 'Forward button to account',
                                     ),
                                     SizedBox(width: 20),
                                   ],
                                 )

                               ],
                             )
                         )
                       )
                      ]
                  ),
                ),
              ),
              const SizedBox(height: 50),

              // Personal Section
              SizedBox(
              width: 400,
              height: 220,
              child:  DecoratedBox(
              decoration:  BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          child: Text(
                              'Personal',
                              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600, color: HexColor(accentColor))
                          ),
                      ),
                      ProfileMenu(title: "Account", subtitle: "Detail your profile information", icon: CupertinoIcons.person, onPress: () {Navigator.pushNamed(context, '/account');}),
                      const Seperator(),
                      ProfileMenu(title: "Change Password", subtitle: "Change to your new password", icon: CupertinoIcons.lock, onPress: () {Navigator.pushNamed(context, '/change-password');}),
                    ],
                ),
              ),
              ),
              const SizedBox(height: 50),

              // Other Section
              SizedBox(
                width: 400,
                height: 280,
                child:  DecoratedBox(
                  decoration:  BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        child: Text(
                            'Other',
                            style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600, color: HexColor(accentColor))
                        ),
                      ),
                      ProfileMenu(title: "Attendance", subtitle: "Edit your attendance", icon: CupertinoIcons.doc_person, onPress: () {}),
                      const Seperator(),
                      ProfileMenu(title: "Notification Settings", subtitle: "Edit your notifications", icon: CupertinoIcons.bell, onPress: () {}),
                      const Seperator(),
                      ProfileMenu(title: "Sign Out", subtitle: "Sign out of the app", textColor: Colors.red, icon: CupertinoIcons.square_arrow_right, onPress: () {}),
                    ],
                  ),
                ),
              ),
          ]
          ),
        )
      ),
    );
  }
}

class Seperator extends StatelessWidget {
  const Seperator({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 5),
          Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 330,height: 2, child: DecoratedBox(
                decoration:  BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                )
            )
            ),
          ],
        ),
        const SizedBox(height: 5),
      ],
    );

  }
}

class ProfileMenu extends StatelessWidget {
  const ProfileMenu({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onPress,
    this.endIcon = true,
    this.textColor,

}) : super(key: key);

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onPress;
  final bool endIcon;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onPress,
      leading: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                color: Colors.transparent,
              ),
              child: Icon(
                icon,
                color: Colors.blue,
                size: 28.0,
                semanticLabel: 'Text to announce in accessibility modes',
              ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              title,
              style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500).apply(color: textColor)
          ),
          Text(
              subtitle,
              style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w300).apply(color: Colors.grey)
          ),
        ],
      ),
      trailing: endIcon ? Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: Colors.transparent,
                  ),
                  child: const Icon(
                    CupertinoIcons.chevron_forward,
                    color: Colors.black,
                    size: 18.0,
                    semanticLabel: 'Forward button to account',
                  ),
                ) : null,
    );
  }
}
