import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/user_profile.dart';

/// All Firestore reads/writes for user data funnel through here so the
/// "Delete Account" flow can be certain it has covered every collection.
///
/// Firestore layout:
///   users/{uid}                          -> profile doc
///   users/{uid}/sleepSessions/{sessionId} -> one per sleep session
///   users/{uid}/aiConversations/{msgId}   -> Kitty AI chat history
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  Future<void> createInitialProfile({
    required String uid,
    required bool isGuest,
    String? displayName,
  }) async {
    final profile = UserProfile.newForUid(uid, isGuest: isGuest, displayName: displayName);
    await _userDoc(uid).set(profile.toMap());
  }

  Future<UserProfile?> getProfile(String uid) async {
    final snap = await _userDoc(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return UserProfile.fromMap(uid, snap.data()!);
  }

  Stream<UserProfile?> watchProfile(String uid) {
    return _userDoc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return UserProfile.fromMap(uid, snap.data()!);
    });
  }

  Future<void> updateProfileFields(String uid, Map<String, dynamic> fields) async {
    await _userDoc(uid).update({
      ...fields,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> saveOnboardingData(UserProfile profile) async {
    await _userDoc(profile.uid).set(
      profile.copyWith(onboardingComplete: true).toMap(),
      SetOptions(merge: true),
    );
  }

  /// Deletes the profile doc plus every subcollection. Firestore does not
  /// cascade-delete subcollections automatically, so each is walked and
  /// batch-deleted explicitly — this is the piece store reviewers check
  /// for when auditing a "Delete Account" flow.
  Future<void> deleteAllUserData(String uid) async {
    final userRef = _userDoc(uid);

    for (final sub in ['sleepSessions', 'aiConversations', 'settings']) {
      await _deleteSubcollection(userRef.collection(sub));
    }

    await userRef.delete();
  }

  Future<void> _deleteSubcollection(CollectionReference<Map<String, dynamic>> ref) async {
    const batchSize = 200;
    QuerySnapshot<Map<String, dynamic>> snap = await ref.limit(batchSize).get();

    while (snap.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snap.docs.length < batchSize) break;
      snap = await ref.limit(batchSize).get();
    }
  }
}
