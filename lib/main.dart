import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'admin_screen.dart';
import 'nav/nav_items.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/school_dashboard_screen.dart';
import 'screens/company_dashboard_screen.dart';
import 'screens/party_dashboard_screen.dart';
import 'dash_screens/calendar_screen.dart';
import 'dash_screens/payments_screen.dart';
import 'dash_screens/notifications_screen.dart';
import 'firebase_options.dart';
import 'theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Dashboard App',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            textTheme: const TextTheme(
              displayLarge: TextStyle(fontSize: 72.0, fontWeight: FontWeight.bold),
              titleLarge: TextStyle(fontSize: 36.0, fontStyle: FontStyle.italic),
              bodyMedium: TextStyle(fontSize: 14.0, fontFamily: 'Hind'),
            ),
          ),
          darkTheme: ThemeData.dark(),
          themeMode: themeProvider.themeMode,
          initialRoute: '/onboarding',
          routes: {
            '/admin-panel': (context) => AdminPanelScreen(),
            '/login': (context) => const LoginScreen(),
            '/onboarding': (context) => const OnBoardingScreen(),
            '/signup': (context) => const SignUpScreen(),
            '/profile': (context) => const ProfileScreen(
              username: '',
              email: '',
              userType: '',
              userId: '',
            ),
            '/settings': (context) => const SettingsScreen(),
            '/school-dashboard': (context) => const SchoolDashboardScreen(
              username: '', // Replace with actual username
              userId: '', // Replace with actual userId
            ),
            '/company-dashboard': (context) => const CompanyDashboardScreen(
              username: '', // Replace with actual username
              userId: '', // Replace with actual userId
            ),
            '/party-dashboard': (context) => const PartyDashboardScreen(
              username: '', // Replace with actual username
              userId: '', // Replace with actual userId
            ),
            '/calendar': (context) => const CalendarScreen(),
            '/payments': (context) => const PaymentsScreen(),
            '/notifications': (context) => const NotificationsScreen(),
          },
          onUnknownRoute: (settings) => MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      },
    );
  }
}

void navigateToAdminScreen(BuildContext context) async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists && userDoc['role'] == 'admin') {
      Navigator.pushNamed(context, '/admin-panel');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to access the admin panel.')),
      );
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please log in first.')),
    );
  }
}
