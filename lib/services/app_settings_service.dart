import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppSettings {
  final int dailyLimitMinutes;
  final String avatarAsset;
  final String avatarName;

  const AppSettings({
    required this.dailyLimitMinutes,
    required this.avatarAsset,
    required this.avatarName,
  });

  factory AppSettings.defaultSettings() {
    return const AppSettings(
      dailyLimitMinutes: 30,
      avatarAsset: "assets/icons/chat.png",
      avatarName: "Arkadaşın",
    );
  }

  factory AppSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return AppSettings.defaultSettings();

    return AppSettings(
      dailyLimitMinutes:
          data["dailyLimitMinutes"] is int ? data["dailyLimitMinutes"] : 30,
      avatarAsset: (data["avatarAsset"] ?? "assets/icons/chat.png").toString(),
      avatarName: (data["avatarName"] ?? "Arkadaşın").toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "dailyLimitMinutes": dailyLimitMinutes,
      "avatarAsset": avatarAsset,
      "avatarName": avatarName,
      "updatedAt": FieldValue.serverTimestamp(),
    };
  }
}

class AppSettingsService {
  static final _db = FirebaseFirestore.instance;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>>? get _ref {
    final uid = _uid;
    if (uid == null) return null;

    return _db
        .collection("users")
        .doc(uid)
        .collection("settings")
        .doc("appSettings");
  }

  static Stream<AppSettings> watchSettings() {
    final ref = _ref;

    if (ref == null) {
      return Stream.value(AppSettings.defaultSettings());
    }

    return ref.snapshots().map((doc) {
      return AppSettings.fromMap(doc.data());
    });
  }

  static Future<AppSettings> getSettings() async {
    final ref = _ref;

    if (ref == null) {
      return AppSettings.defaultSettings();
    }

    final doc = await ref.get();

    if (!doc.exists) {
      final defaults = AppSettings.defaultSettings();
      await ref.set(defaults.toMap());
      return defaults;
    }

    return AppSettings.fromMap(doc.data());
  }

  static Future<void> updateSettings({
    required int dailyLimitMinutes,
    required String avatarAsset,
    required String avatarName,
  }) async {
    final ref = _ref;
    if (ref == null) return;

    await ref.set(
      {
        "dailyLimitMinutes": dailyLimitMinutes,
        "avatarAsset": avatarAsset,
        "avatarName": avatarName,
        "updatedAt": FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> saveSettings({
    required int dailyLimitMinutes,
    required String avatarAsset,
    required String avatarName,
  }) async {
    await updateSettings(
      dailyLimitMinutes: dailyLimitMinutes,
      avatarAsset: avatarAsset,
      avatarName: avatarName,
    );
  }
}