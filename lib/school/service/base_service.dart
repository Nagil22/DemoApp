
import 'package:cloud_firestore/cloud_firestore.dart';

class BaseFoundationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> validateUserAccess(String userId, String schoolId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final userRole = userData['role'] as String?;
      final userSchool = userData['schoolCode'] as String?;

      return userRole == 'teacher' && userSchool == schoolId;
    } catch (e) {
      return false;
    }
  }

  Future<bool> validateDataStructure(String schoolId) async {
    try {
      final collections = [
        'classes',
        'grades',
        'attendance',
        'users',
        'notifications'
      ];

      for (var collection in collections) {
        final snapshot = await _firestore
            .collection('schools')
            .doc(schoolId)
            .collection(collection)
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) {
          await _initializeCollection(schoolId, collection);
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _initializeCollection(String schoolId, String collection) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection(collection)
        .doc('_template')
        .set({
      'initialized': true,
      'timestamp': FieldValue.serverTimestamp()
    });
  }
}