import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/reunion.dart';

class ReunionDao {
  ReunionDao({FirebaseFirestore? firestore})
    : _fs = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _fs;

  CollectionReference<Map<String, dynamic>> get _col =>
      _fs.collection('reunions');

  void _logError(String where, Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('[ReunionDao.$where] error: $error');
      debugPrint(stack.toString());
    }
  }

  /// CREATE → retourne l'id créé
  Future<String> add(Reunion r) async {
    try {
      final doc = _col.doc();
      final data = r.copyWith(id: doc.id, updatedAt: DateTime.now()).toMap();
      await doc.set(data);
      return doc.id;
    } catch (e, st) {
      _logError('add', e, st);
      rethrow;
    }
  }

  /// UPDATE (id requis)
  Future<void> update(Reunion r) async {
    if (r.id == null) {
      throw ArgumentError('Reunion.update: id manquant');
    }
    try {
      await _col
          .doc(r.id)
          .update(r.copyWith(updatedAt: DateTime.now()).toMap());
    } catch (e, st) {
      _logError('update', e, st);
      rethrow;
    }
  }

  /// DELETE
  Future<void> delete(String id) async {
    try {
      await _col.doc(id).delete();
    } catch (e, st) {
      _logError('delete', e, st);
      rethrow;
    }
  }

  /// READ by id
  Future<Reunion?> getById(String id) async {
    try {
      final snap = await _col.doc(id).get();
      if (!snap.exists) return null;
      return Reunion.fromMap(snap.data()!, id: snap.id);
    } catch (e, st) {
      _logError('getById($id)', e, st);
      return null;
    }
  }

  /// READ range (from/to inclusifs si fournis, sinon tout)
  Future<List<Reunion>> fetchRange({DateTime? from, DateTime? to}) async {
    try {
      Query<Map<String, dynamic>> q = _col.orderBy('date');
      if (from != null) {
        q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
      }
      if (to != null) {
        q = q.where('date', isLessThanOrEqualTo: Timestamp.fromDate(to));
      }

      final res = await q.get();
      return res.docs.map((d) => Reunion.fromMap(d.data(), id: d.id)).toList();
    } catch (e, st) {
      _logError('fetchRange', e, st);
      rethrow;
    }
  }

  /// KPI: nombre de réunions sur une année
  Future<int> totalCount({required int year}) async {
    try {
      final from = DateTime(year, 1, 1);
      final to = DateTime(year, 12, 31, 23, 59, 59, 999);

      final res = await _col
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(to))
          .count()
          .get();

      return res.count ?? 0; // <- valeur par défaut si null
    } catch (e, st) {
      _logError('totalCount($year)', e, st);
      rethrow;
    }
  }
}
