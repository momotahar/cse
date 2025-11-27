// lib/services/syndic_event_dao.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/syndic_event.dart';

class SyndicEventDao {
  final _c = FirebaseFirestore.instance.collection('syndic_events');

  void _logError(String where, Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('[SyndicEventDao.$where] error: $error');
      debugPrint(stack.toString());
    }
  }

  /// Stream des évènements dans l’intervalle [from, to[ (mois courant, etc.)
  Stream<List<SyndicEvent>> streamRange(DateTime from, DateTime to) {
    try {
      final f = Timestamp.fromDate(from.toUtc());
      final t = Timestamp.fromDate(to.toUtc());

      return _c
          .where('date', isGreaterThanOrEqualTo: f)
          .where('date', isLessThan: t)
          .orderBy(
            'date',
          ) // obligatoire quand on filtre par range sur le même champ
          .snapshots()
          .map(
            (s) => s.docs
                .map(
                  (d) => SyndicEvent.fromDoc(
                    d as DocumentSnapshot<Map<String, dynamic>>,
                  ),
                )
                .toList(),
          );
    } catch (e, st) {
      _logError('streamRange', e, st);
      // flux de secours pour ne pas faire crasher les listeners
      return const Stream<List<SyndicEvent>>.empty();
    }
  }

  /// Création : map déjà au bon format via `toMap()` du modèle
  Future<String> create(SyndicEvent e) async {
    try {
      final payload = e.toMap()..remove('updated_at'); // créé côté update
      final ref = await _c.add(payload);
      await ref.update({'id': ref.id});
      return ref.id;
    } catch (e, st) {
      _logError('create', e, st);
      rethrow;
    }
  }

  /// Mise à jour partielle (merge) + estampille serveur
  Future<void> update(String id, Map<String, dynamic> patch) async {
    try {
      await _c.doc(id).set({
        ...patch,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, st) {
      _logError('update', e, st);
      rethrow;
    }
  }

  Future<void> remove(String id) async {
    try {
      await _c.doc(id).delete();
    } catch (e, st) {
      _logError('remove', e, st);
      rethrow;
    }
  }

  static String currentUid() => FirebaseAuth.instance.currentUser?.uid ?? '';
}
