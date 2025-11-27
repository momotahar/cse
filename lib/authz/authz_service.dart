// lib/authz/authz_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthzService extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  bool _loading = false;
  bool get loading => _loading;

  String? _email;
  String? get email => _email;

  bool _isAdmin = false;
  bool get isAdmin => _isAdmin;

  Set<String> _features = {};
  bool can(String feature) => _isAdmin || _features.contains(feature);

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  AuthzService() {
    _authSub = _auth.authStateChanges().listen((u) {
      _email = u?.email;
      if (u == null) {
        _teardownUserDoc();
        _isAdmin = false;
        _features = {};
        notifyListeners();
      } else {
        _bootstrapUser(u.uid, u.email);
      }
    });
  }

  Future<void> _bootstrapUser(String uid, String? email) async {
    _loading = true;
    notifyListeners();
    try {
      final ref = _db.collection('users').doc(uid);
      final snap = await ref.get();
      if (!snap.exists) {
        // IMPORTANT : ne pas écrire role/features ici (règles les bloquent)
        await ref.set({
          'email': email,
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      _listenUserDoc(uid);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _listenUserDoc(String uid) {
    _userDocSub?.cancel();
    _userDocSub = _db.collection('users').doc(uid).snapshots().listen((doc) {
      if (!doc.exists) {
        _isAdmin = false;
        _features = {};
      } else {
        final data = doc.data()!;
        _isAdmin = (data['role'] ?? 'user') == 'admin';
        final list = (data['features'] as List?)?.cast<String>() ?? const [];
        _features = Set<String>.from(list);
      }
      notifyListeners();
    });
  }

  void _teardownUserDoc() {
    _userDocSub?.cancel();
    _userDocSub = null;
  }

  Future<void> forceRefreshNow() async {
    // Pour compat avec ton AuthBootstrapper
    final u = _auth.currentUser;
    if (u != null) {
      await _bootstrapUser(u.uid, u.email);
    }
  }

  // Helpers admin (appelés depuis l’écran d’admin)
  Future<void> setAdmin(String uid, bool admin) async {
    await _db.collection('users').doc(uid).set({
      'role': admin ? 'admin' : 'user',
    }, SetOptions(merge: true));
  }

  Future<void> setFeatures(String uid, Set<String> features) async {
    await _db.collection('users').doc(uid).set({
      'features': features.toList(),
    }, SetOptions(merge: true));
  }

  // Auth UI helpers
  Future<void> signOut() async => _auth.signOut();

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }
}
