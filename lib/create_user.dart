import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> createUser(String email, String password, String username, String role) async {
  try {
    // Create user with Firebase Authentication
    UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Add additional user info in Firestore
    await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
      'username': username,
      'email': email,
      'role': role, // Dynamically assign role
    });
  } catch (e) {
    print('Error: $e');
    rethrow; // Rethrow to handle it in the UI
  }
}
