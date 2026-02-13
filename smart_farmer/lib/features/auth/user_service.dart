import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String? phone;
  final String? email;
  final String role;
  final DateTime createdAt;

  const UserProfile({
    required this.uid,
    this.phone,
    this.email,
    this.role = 'farmer',
    required this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      role: map['role'] as String? ?? 'farmer',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phone': phone,
      'email': email,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

class UserService {
  final FirebaseFirestore _firestore;

  UserService({FirebaseFirestore? firestore})
    : _firestore =
          firestore ??
          FirebaseFirestore.instanceFor(
            app: FirebaseFirestore.instance.app,
            databaseId: 'smart-farmer-kenya',
          );

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<void> createProfileIfAbsent({
    required String uid,
    String? phone,
    String? email,
  }) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) {
      final profile = UserProfile(
        uid: uid,
        phone: phone,
        email: email,
        createdAt: DateTime.now(),
      );
      await _users.doc(uid).set(profile.toMap());
    }
  }

  Future<UserProfile?> getProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserProfile.fromMap(doc.data()!);
    }
    return null;
  }
}
