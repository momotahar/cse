// lib/services/depots_dao.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/depot.dart';

class DepotsDao {
  final _c = FirebaseFirestore.instance
      .collection('depots')
      .withConverter<Depot>(
        fromFirestore: (snap, _) => Depot.fromMap(snap.id, snap.data()!),
        toFirestore: (d, _) => d.toMap(),
      );

  // ref brut (sans converter) pour écrire un Map
  final _raw = FirebaseFirestore.instance.collection('depots');

  void _logError(String where, Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('[DepotsDao.$where] error: $error');
      debugPrint(stack.toString());
    }
  }

  Stream<List<Depot>> streamAll() {
    try {
      return _c
          .orderBy('nom')
          .snapshots()
          .map((s) => s.docs.map((d) => d.data()).toList());
    } catch (e, st) {
      _logError('streamAll', e, st);
      // flux de secours pour éviter un crash du listener
      return const Stream<List<Depot>>.empty();
    }
  }

  Future<List<Depot>> listAll() async {
    try {
      final snap = await _c.orderBy('nom').get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e, st) {
      _logError('listAll', e, st);
      rethrow;
    }
  }

  Future<String> create({
    required String nom,
    required String adresse,
    String? ville,
    String? cp,
  }) async {
    try {
      final ref = await _c.add(
        Depot(id: '_', nom: nom, adresse: adresse, ville: ville, cp: cp),
      );
      await ref.update({'id': ref.id});
      return ref.id;
    } catch (e, st) {
      _logError('create', e, st);
      rethrow;
    }
  }

  // <-- ICI on passe par _raw pour accepter un Map
  Future<void> update(String id, Map<String, dynamic> patch) async {
    try {
      await _raw.doc(id).set(patch, SetOptions(merge: true));
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
}
