import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SavedPainting {
  final String id;
  final String title;
  final String imageBase64;
  final DateTime createdAt;
  final DateTime expiresAt;

  const SavedPainting({
    required this.id,
    required this.title,
    required this.imageBase64,
    required this.createdAt,
    required this.expiresAt,
  });

  Uint8List get bytes {
    final cleanBase64 = imageBase64.contains(",")
        ? imageBase64.split(",").last
        : imageBase64;

    return base64Decode(cleanBase64);
  }

  factory SavedPainting.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return SavedPainting(
      id: doc.id,
      title: data["title"] ?? "Boyama",
      imageBase64: data["imageBase64"] ?? "",
      createdAt:
          (data["createdAt"] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt:
          (data["expiresAt"] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ParentSavedPaintingsStore {
  static const int keepDays = 7;

  static Timer? _cleanupTimer;

  static FirebaseFirestore get _firestore =>
      FirebaseFirestore.instance;

  static FirebaseAuth get _auth =>
      FirebaseAuth.instance;

  static String get _uid {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception("Kullanıcı giriş yapmamış");
    }

    return user.uid;
  }

  static CollectionReference<Map<String, dynamic>>
      get _collection =>
          _firestore
              .collection("users")
              .doc(_uid)
              .collection("savedPaintings");

  static Future<void> startAutoCleanup() async {
    await cleanupExpired();

    _cleanupTimer?.cancel();

    _cleanupTimer = Timer.periodic(
      const Duration(hours: 6),
      (_) async {
        await cleanupExpired();
      },
    );
  }

  static void stopAutoCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }

  static Future<void> save({
    required String imageBase64,
    String title = "Boyama",
  }) async {
    final now = DateTime.now();

    final expiresAt = now.add(
      const Duration(days: keepDays),
    );

    await _collection.add({
      "title": title,
      "imageBase64": imageBase64,
      "createdAt": Timestamp.fromDate(now),
      "expiresAt": Timestamp.fromDate(expiresAt),
    });
  }

  static Future<List<SavedPainting>> getPaintings() async {
    await cleanupExpired();

    final snapshot = await _collection
        .orderBy("createdAt", descending: true)
        .get();

    return snapshot.docs
        .map((doc) => SavedPainting.fromDoc(doc))
        .toList();
  }

  static Future<void> deletePainting(String id) async {
    await _collection.doc(id).delete();
  }

  static Future<void> cleanupExpired() async {
    final now = DateTime.now();

    final snapshot = await _collection.get();

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final expiresAt =
          (data["expiresAt"] as Timestamp?)?.toDate();

      if (expiresAt == null) continue;

      if (now.isAfter(expiresAt)) {
        await doc.reference.delete();
      }
    }
  }

  static Future<void> clearAll() async {
    final snapshot = await _collection.get();

    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}