import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Firestore Structure')),
        body: FirestoreStructure(),
      ),
    );
  }
}

class FirestoreStructure extends StatelessWidget {
  FirestoreStructure({super.key});

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getCollectionStructure(CollectionReference collectionRef, {int depth = 0}) async {
    Map<String, dynamic> structure = {};

    if (depth > 2) return structure; // Limit depth to avoid infinite recursion

    QuerySnapshot querySnapshot = await collectionRef.limit(1).get();

    for (var doc in querySnapshot.docs) {
      structure[collectionRef.id] = {};
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      for (var entry in data.entries) {
        if (entry.value is DocumentReference) {
          structure[collectionRef.id][entry.key] = await getCollectionStructure(
            (entry.value as DocumentReference).parent,
            depth: depth + 1,
          );
        } else {
          structure[collectionRef.id][entry.key] = entry.value.runtimeType.toString();
        }
      }

      // Get subcollections
      List<CollectionReference> subcollections = await doc.reference.listCollections();
      for (var subcoll in subcollections) {
        var subStructure = await getCollectionStructure(subcoll, depth: depth + 1);
        structure[collectionRef.id].addAll(subStructure);
      }
    }

    return structure;
  }

  Future<Map<String, dynamic>> getDatabaseStructure() async {
    Map<String, dynamic> dbStructure = {};
    QuerySnapshot rootCollections = await firestore.collection('__root__').get();

    for (var doc in rootCollections.docs) {
      String collectionName = doc.id;
      var collStructure = await getCollectionStructure(firestore.collection(collectionName));
      dbStructure.addAll(collStructure);
    }

    return dbStructure;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: getDatabaseStructure(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No data available'));
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              snapshot.data.toString(),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        );
      },
    );
  }
}

extension on DocumentReference<Object?> {
  listCollections() {}
}