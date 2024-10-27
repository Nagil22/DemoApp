import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Import your custom screens and widgets
import 'nav/nav_items.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/forgot_password.dart';
import 'screens/reset_password.dart';
import 'screens/profile/account_page.dart';
import 'screens/profile/change_password.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/signup_screen.dart';
import 'school/student_dashboard_screen.dart';
import 'school/parent_dashboard_screen.dart';
import 'school/teacher_dashboard_screen.dart';
import 'school/admin_dashboard_screen.dart';
import 'screens/company_dashboard_screen.dart';
import 'screens/party_dashboard_screen.dart';
import 'dash_screens/payments_screen.dart';
import 'admin_screen.dart';
import 'firebase_options.dart';
import 'theme_provider.dart';
import 'structure.dart';

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
        // Set up foreground message handler
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (kDebugMode) {
            print('Received a message in the foreground: ${message.messageId}');
          }
          if (message.notification != null) {
            if (kDebugMode) {
              print('Message also contained a notification: ${message.notification}');
            }
          }
        });

        return MaterialApp(
          title: 'Dashboard App',
          theme: ThemeData(
            scaffoldBackgroundColor: const Color(0xFFEFEFEF),
            primarySwatch: Colors.blue,
            cardTheme: CardTheme(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            dividerTheme: DividerThemeData(
              space: 1,
              thickness: 1,
              color: Colors.grey[300],
            ),
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
                  return const AdminPanelScreen(userId: "", username: "", email: "");
                } else {
                  return showOnBoarding ? const OnBoardingScreen() : const LoginScreen();
                }
              }
            },
          ),
          routes: {
            '/admin-panel': (context) => const AdminPanelScreen(userId: "", username: "", email: ""),
            '/login': (context) => const LoginScreen(),
            '/onboarding': (context) => const OnBoardingScreen(),
            '/signup': (context) => const SignUpScreen(),
            '/forgot': (context) => const ForgotPasswordScreen(),
            '/reset': (context) => const ResetPasswordScreen(),
            '/account': (context) => const AccountScreen(userId: "", username: "", email: "", userType: ""),
            '/profile': (context) => const ProfileScreen(username: '', email: '', userType: '', userId: '', accentColor: Colors.blueAccent,),
            '/change-password': (context) => const ChangePasswordScreen(),
            '/settings': (context) => const SettingsScreen(),
            '/school-dashboard': (context) => const StudentDashboardScreen(username: '', userId: '', schoolCode: '', schoolName: ''),
            '/student-dashboard': (context) => const StudentDashboardScreen(username: '', userId: '', schoolCode: '', schoolName: ''),
            '/parent-dashboard': (context) => const ParentDashboardScreen(username:'', userId: '', schoolCode: '', schoolName: ''),
            '/teacher-dashboard': (context) => const TeacherDashboardScreen(username: '', userId:'', schoolCode: '', schoolName: '', ),
            '/admin-dashboard': (context) => const AdminDashboardScreen(username: '', userId: '', schoolName: '', schoolCode: '',),
            '/company-dashboard': (context) => const CompanyDashboardScreen(username: '', userId: ''),
            '/party-dashboard': (context) => const PoliticalPartyDashboardScreen(username: '', userId: ''),
            '/payments': (context) => const PaymentsScreen(schoolCode: '', userId: '',),
            '/notifications': (context) => const NotificationsScreen(),
            '/firestore-structure': (context) => FirestoreStructure(),
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