import 'package:demo/screens/profile/account_page.dart';
import 'package:demo/screens/profile/profile_menus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

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
  String _username = '';
  String _userType = '';
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _email = widget.email;
    final User? user = _auth.currentUser;

    if( user != null){
      // _username = user.displayName!;
      _email = user.email!;
      // getUser(user);
      _userType = 'superadmin';
    }

  }

  void getUser(user) async {
    DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore
        .instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists && userDoc.data()!.containsKey('role')) {
      _userType = userDoc.data()!['role'];
    }
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

  Widget _buildTextSectionBasedOnRole(role) {
    switch (_userType) {
    case 'superadmin':
      return const Text(
      'Super Admin',
      style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Colors.white),
      );
      case 'school':
        return const Text(
          'School International Academy',
          style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Colors.white),
        );
      case 'teacher':
        return const Text(
          'Teacher at School International Academy',
          style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Colors.white),
        );
      case 'student':
        return const Text(
          'Year 12 at School International Academy',
          style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Colors.white),
        );
    default:
      return const Text(
      'Year 12 at School International Academy',
      style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w600, color: Colors.white),
      );
    }
  }

  Widget _buildPersonalSectionBasedOnRole(role) {
    switch (_userType) {
      case 'superadmin':
            return Column(
              children: [
                    const Seperator(),
                    ProfileMenu(title: "Edit admins", subtitle: "Edit all admins", icon: CupertinoIcons.person_2, onPress: () {Navigator.pushNamed(context, '/change-password');})
              ]);
      case 'teacher':
        return Column(
            children: [
              const Seperator(),
              ProfileMenu(title: "Edit class details", subtitle: "Edit your school details", icon: CupertinoIcons.book, onPress: () {Navigator.pushNamed(context, '/change-password');})
            ]);


      case 'school':
        return Column(
            children: [
              const Seperator(),
              ProfileMenu(title: "Edit school details", subtitle: "Edit school details", icon: CupertinoIcons.building_2_fill, onPress: () {Navigator.pushNamed(context, '/change-password');})
            ]);

      case 'parent':
        return Column(
            children: [
              const Seperator(),
              ProfileMenu(title: "Manage Children", subtitle: "Manage children accounts", icon: CupertinoIcons.person_3, onPress: () {Navigator.pushNamed(context, '/change-password');})
            ]);
      default:
      return Column(
        children: [
          ProfileMenu(title: "Change Password", subtitle: "Change to your new password", icon: CupertinoIcons.lock, onPress: () {Navigator.pushNamed(context, '/change-password');})
        ]);
    }
  }

  Widget _buildOtherSectionBasedOnRole(role) {
    switch (_userType) {
      case 'superadmin':
        return Column(
            children: [
              const Seperator(),
              ProfileMenu(title: "Notification Settings", subtitle: "Edit your notifications", icon: CupertinoIcons.bell, onPress: () {}),
            ]);

      case 'student':
        return Column(
            children: [
              ProfileMenu(title: "Attendance", subtitle: "Manage your attendance", icon: CupertinoIcons.doc_person, onPress: () {}),
              const Seperator(),
              ProfileMenu(title: "Notification Settings", subtitle: "Edit your notifications", icon: CupertinoIcons.bell, onPress: () {}),
            ]);

      case 'parent':
        return Column(
            children: [
              ProfileMenu(title: "Attendance", subtitle: "See children attendance", icon: CupertinoIcons.doc_person, onPress: () {}),
              const Seperator(),
              ProfileMenu(title: "Manage School fees", subtitle: "See history of paid school fees", icon: CupertinoIcons.doc_on_doc, onPress: () {Navigator.pushNamed(context, '/change-password');}),
              const Seperator(),
              ProfileMenu(title: "Manage Report cards", subtitle: "Manage report cards", icon: CupertinoIcons.doc_on_doc, onPress: () {Navigator.pushNamed(context, '/change-password');})
            ]);

      case 'school':
        return Column(
            children: [
              ProfileMenu(title: "School fees payments", subtitle: "Manage payment methods", icon: CupertinoIcons.creditcard, onPress: () {}),
              const Seperator(),
              ProfileMenu(title: "See all students", subtitle: "Manage all students details", icon: CupertinoIcons.person_3, onPress: () {Navigator.pushNamed(context, '/change-password');})
            ]);
      default:
        return Column(
            children: [
              ProfileMenu(title: "Attendance", subtitle: "Edit your attendance", icon: CupertinoIcons.doc_person, onPress: () {}),
            ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HexColor.fromHex(profileBgColor),
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
                        const SizedBox(height: 20),
                        Row(
                            children: [
                              const SizedBox(width: 20),
                               CircleAvatar(
                                radius: 25,
                                backgroundColor: Colors.white,
                                child:  Image.asset(
                                    "assets/illustrations/profile.png",
                                    height:100
                                ),
                                // child: Icon(Icons.person, size: 25, color: Colors.white),
                              ),
                              const SizedBox(width: 20),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_userType}',
                                    style: const TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600,),
                                    textAlign: TextAlign.left,
                                  ),
                                  Text(
                                    '${_email}',
                                    style: TextStyle(fontSize: 13.0, color: HexColor.fromHex(accentColor)),
                                    textAlign: TextAlign.left,
                                  ),
                                ],
                              ),
                              const Spacer(),
                            ],
                        ),
                       const SizedBox(height: 10),
                       SizedBox(
                         width: 400,
                         height: 80,
                         child:  DecoratedBox(
                             decoration:  BoxDecoration(
                               // color: Colors.blue,
                               gradient: const LinearGradient(
                                 begin: Alignment.topLeft,
                                 end: Alignment.bottomRight,
                                 colors: [Colors.blue, Colors.blueAccent],
                               ),
                               borderRadius: BorderRadius.circular(20),
                             ),
                             child:  Column(
                               mainAxisAlignment: MainAxisAlignment.center,
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Row(
                                   // mainAxisAlignment: MainAxisAlignment.center,
                                   children: [
                                     const SizedBox(width: 20),
                                     const Icon(
                                       CupertinoIcons.building_2_fill,
                                       color: Colors.white,
                                       size: 20.0,
                                       semanticLabel: 'Text to announce in accessibility modes',
                                     ),
                                     const SizedBox(width: 20),
                                     Flexible(
                                       child:
                                       _buildTextSectionBasedOnRole(_userType),
                                     ),
                                     const Spacer(),
                                     const Icon(
                                       CupertinoIcons.chevron_forward,
                                       color: Colors.white,
                                       size: 18.0,
                                       semanticLabel: 'Forward button to account',
                                     ),
                                     const SizedBox(width: 20),
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
              const SizedBox(height: 40),

              // Personal Section
              Container(
              width: 400,
              // height: 220,
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
                              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600, color: HexColor.fromHex(accentColor))
                          ),
                      ),
                      ProfileMenu(title: "Account", subtitle: "Detail your profile information", icon: CupertinoIcons.person, onPress: () {Navigator.pushNamed(context, '/account', arguments: {
                        'userId': widget.userId,
                        'username': _username,
                        'email': _email,
                        'userType': _userType
                      });}),
                      const Seperator(),
                      ProfileMenu(title: "Change Password", subtitle: "Change to your new password", icon: CupertinoIcons.lock, onPress: () {Navigator.pushNamed(context, '/change-password');}),
                      _buildPersonalSectionBasedOnRole(_userType),
                      const SizedBox(height: 10),
                    ],
                ),
              ),
              ),
              const SizedBox(height: 40),

              // Other Section
              Container(
                width: 400,
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
                            style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600, color: HexColor.fromHex(accentColor))
                        ),
                      ),
                      _buildOtherSectionBasedOnRole(_userType),
                      const Seperator(),
                      ProfileMenu(title: "Notification Settings", subtitle: "Edit your notifications", icon: CupertinoIcons.bell, onPress: () {}),
                      const Seperator(),
                      ProfileMenu(title: "Sign Out", subtitle: "Sign out of the app", textColor: Colors.red, icon: CupertinoIcons.square_arrow_right, onPress: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, '/login');
                        }
                      },
                      ),
                      const SizedBox(height: 10),
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
