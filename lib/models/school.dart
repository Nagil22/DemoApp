import 'package:cloud_firestore/cloud_firestore.dart';

class School {
  final String id;
  final String name;
  final String code;
  final String type;
  final String status;
  final Map<String, dynamic> config;
  final String? adminId;
  final DateTime createdAt;

  School({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.status,
    required this.config,
    this.adminId,
    required this.createdAt,
  });

  factory School.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return School(
      id: doc.id,
      name: data['name'] ?? '',
      code: data['code'] ?? '',
      type: data['type'] ?? '',
      status: data['status'] ?? 'inactive',
      config: data['config'] ?? {},
      adminId: data['adminId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'code': code,
      'type': type,
      'status': status,
      'config': config,
      'adminId': adminId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Helper method to create a new school
  static Future<School> create({
    required String name,
    required String code,
    required String type,
    required Map<String, dynamic> config,
  }) async {
    final docRef = await FirebaseFirestore.instance.collection('schools').add({
      'name': name,
      'code': code,
      'type': type,
      'status': 'active',
      'config': config,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final doc = await docRef.get();
    return School.fromFirestore(doc);
  }

  // Helper method to fetch a school by ID
  static Future<School?> getById(String id) async {
    final doc = await FirebaseFirestore.instance
        .collection('schools')
        .doc(id)
        .get();

    if (!doc.exists) return null;
    return School.fromFirestore(doc);
  }

  // Helper method to update school status
  Future<void> updateStatus(String newStatus) async {
    await FirebaseFirestore.instance
        .collection('schools')
        .doc(id)
        .update({'status': newStatus});
  }

  // Helper method to update school admin
  Future<void> assignAdmin(String adminId) async {
    await FirebaseFirestore.instance
        .collection('schools')
        .doc(id)
        .update({'adminId': adminId});
  }

  // Helper method to update school config
  Future<void> updateConfig(Map<String, dynamic> newConfig) async {
    await FirebaseFirestore.instance
        .collection('schools')
        .doc(id)
        .update({'config': newConfig});
  }
}