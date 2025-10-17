// ignore_for_file: constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Admin initial (bootstrap) — en MINUSCULE
const ADMIN_EMAIL_BOOTSTRAP = 'cret94000@gmail.com'; // <<< change ici

class AuthzService extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  List<String> _features = [];
  bool _isAdmin = false;
  String? _emailId;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _adminDocSub;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  List<String> get features => _features;
  bool get isAdmin => _isAdmin;
  String? get uid => _emailId;

  AuthzService() {
    _auth.userChanges().listen((u) async {
      // refresh token
      try {
        await u?.getIdTokenResult(true);
      } catch (_) {}

      // cleanup anciens listeners
      _adminDocSub = null;
      _userDocSub = null;

      final email = u?.email?.trim().toLowerCase();
      _emailId = email;

      // admin par bootstrap email
      _isAdmin = (email != null && email == ADMIN_EMAIL_BOOTSTRAP);

      if (_emailId == null) {
        _features = [];
        notifyListeners();
        return;
      }

      // 1) écoute de /admins/{email} pour savoir si on est admin
      final adminRef = _db.collection('admins').doc(_emailId!);
      _adminDocSub = adminRef.snapshots();
      _adminDocSub!.listen(
        (snap) {
          final isListedAdmin = snap.exists;
          final newIsAdmin = (email == ADMIN_EMAIL_BOOTSTRAP) || isListedAdmin;
          if (newIsAdmin != _isAdmin) {
            _isAdmin = newIsAdmin;
            notifyListeners();
          }
        },
        onError: (_) {
          /* ignore */
        },
      );

      // 2) s’assurer que /users/{email} existe (créé par soi-même)
      final userRef = _db.collection('users').doc(_emailId!);
      try {
        final exists = (await userRef.get()).exists;
        if (!exists) {
          await userRef.set({
            'email': _emailId,
            'allowed_features': <String>[],
            'created_at': FieldValue.serverTimestamp(),
          });
        }
      } catch (_) {
        // si permission-denied, l’admin créera le doc depuis l’écran Autorisation
      }

      // 3) écoute des features en temps réel
      _userDocSub = userRef.snapshots();
      _userDocSub!.listen(
        (s) {
          _features =
              (s.data()?['allowed_features'] as List?)?.cast<String>() ?? [];
          notifyListeners();
        },
        onError: (_) {
          /* ignore */
        },
      );
    });
  }

  bool can(String feature) => _isAdmin || _features.contains(feature);

  Future<void> reloadProfile() async {
    if (_emailId == null) return;
    final snap = await _db.collection('users').doc(_emailId!).get();
    _features =
        (snap.data()?['allowed_features'] as List?)?.cast<String>() ?? [];
    notifyListeners();
  }
}
