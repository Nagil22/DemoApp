import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'nav/nav_items.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'firebase_options.dart';
import 'theme_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

bool showOnBoarding = true;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final prefs = await SharedPreferences.getInstance();
  showOnBoarding = prefs.getBool('ON_BOARDING') ?? true;

  // Initialize FCM
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();

  // Handle background messages
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => NavItems()),
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('Handling a background message: ${message.messageId}');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Dashboard App',
          theme: ThemeData(
            scaffoldBackgroundColor: const Color(0xFFEFEFEF),
            primarySwatch: Colors.blue,
            textTheme: const TextTheme(
              displayLarge: TextStyle(fontSize: 72.0, fontWeight: FontWeight.bold),
              titleLarge: TextStyle(fontSize: 36.0, fontStyle: FontStyle.italic),
              bodyMedium: TextStyle(fontSize: 14.0, fontFamily: 'Hind'),
            ),
          ),
          darkTheme: ThemeData.dark(),
          themeMode: themeProvider.themeMode,
          home: FutureBuilder(
            future: checkAuthState(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              } else {
                if (snapshot.data == true) {
                  return const LoginScreen();
                } else {
                  return const OnBoardingScreen();
                }
              }
            },
          ),
          routes: const {
            // ... (keep your existing routes)
          },
          onUnknownRoute: (settings) => MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      },
    );
  }
}

Future<bool> checkAuthState() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists && userDoc['role'] == 'SuperAdmin') {
      return true;
    }
  }
  return false;
}

void navigateToAdminScreen(BuildContext context) async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists && userDoc['role'] == 'SuperAdmin') {
      Navigator.pushNamed(context, '/admin-panel');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to access the admin panel. Only SuperAdmins are allowed.')),
      );
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please log in first.')),
    );
  }
}