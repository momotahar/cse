// lib/services/presence_dao.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:cse_kch/models/presence_model.dart';

class PresenceDao {
  static const _collection = 'presences';
  final CollectionReference<Map<String, dynamic>> _col = FirebaseFirestore
      .instance
      .collection(_collection);

  void _logError(String where, Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('[PresenceDao.$where] error: $error');
      debugPrint(stack.toString());
    }
  }

  /// Ajoute 1 présence (NOUVEAU doc à chaque appel) → retourne l'id
  Future<String> add(PresenceModel p) async {
    try {
      final data = Map<String, dynamic>.from(p.toMap());
      data['created_at'] = FieldValue.serverTimestamp();
      data['updated_at'] = FieldValue.serverTimestamp();
      final doc = await _col.add(data); // id auto
      return doc.id;
    } catch (e, st) {
      _logError('add', e, st);
      rethrow;
    }
  }

  /// Ajoute plusieurs présences en une fois (batch)
  Future<void> addMany(List<PresenceModel> items) async {
    if (items.isEmpty) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final p in items) {
        final ref = _col.doc(); // nouveau doc id pour CHAQUE présence
        final data = Map<String, dynamic>.from(p.toMap());
        data['created_at'] = FieldValue.serverTimestamp();
        data['updated_at'] = FieldValue.serverTimestamp();
        batch.set(ref, data);
      }
      await batch.commit();
    } catch (e, st) {
      _logError('addMany', e, st);
      rethrow;
    }
  }

  /// Supprime une présence par id
  Future<void> delete(String id) async {
    try {
      await _col.doc(id).delete();
    } catch (e, st) {
      _logError('delete', e, st);
      rethrow;
    }
  }

  /// Met à jour (sécurisé: n’écrase pas l’id)
  Future<void> update(PresenceModel p) async {
    if (p.id == null) {
      throw ArgumentError('Presence.id manquant pour update');
    }
    try {
      final data = Map<String, dynamic>.from(p.toMap());
      data['updated_at'] = FieldValue.serverTimestamp();
      await _col.doc(p.id).update(data);
    } catch (e, st) {
      _logError('update', e, st);
      rethrow;
    }
  }

  /// Charge toutes les présences (triables côté UI)
  Future<List<PresenceModel>> fetchAll() async {
    try {
      final snap = await _col.get();
      return snap.docs
          .map((d) => PresenceModel.fromMap(d.data(), id: d.id))
          .toList();
    } catch (e, st) {
      _logError('fetchAll', e, st);
      rethrow;
    }
  }

  /// Filtre par intervalle de date (si besoin)
  Future<List<PresenceModel>> fetchByDateRange({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      // Les dates sont au format texte (dd-MM-yyyy) → filtre en mémoire.
      final all = await fetchAll();
      all.retainWhere((p) {
        try {
          final d = _parseUiDate(p.date);
          return !d.isBefore(from) && !d.isAfter(to);
        } catch (_) {
          return false;
        }
      });
      return all;
    } catch (e, st) {
      _logError('fetchByDateRange', e, st);
      rethrow;
    }
  }

  DateTime _parseUiDate(String ddMMyyyy) {
    final parts = ddMMyyyy.split('-'); // dd-MM-yyyy
    final d = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final y = int.parse(parts[2]);
    return DateTime(y, m, d);
  }
}
