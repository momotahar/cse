// lib/services/filiale_dao.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/filiale_model.dart';

const String _kFilialesCol = 'filiales';

class FilialeDAO {
  static final _col = FirebaseFirestore.instance.collection(_kFilialesCol);
  static int _genId() => DateTime.now().millisecondsSinceEpoch;

  static String _norm(String s) => s.trim().toUpperCase();

  /// Vérifie si une abréviation (normalisée) existe déjà
  /// Option `excludeId` pour ignorer la filiale en cours d’édition.
  static Future<bool> abreviationExists(String abrev, {int? excludeId}) async {
    final norm = _norm(abrev);
    final q = await _col
        .where('abreviation_norm', isEqualTo: norm)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return false;
    if (excludeId == null) return true;
    final doc = q.docs.first;
    final data = doc.data();
    final existingId = (data['id'] is int)
        ? data['id'] as int
        : int.tryParse(doc.id);
    return existingId != excludeId;
  }

  // ---------- Helpers ----------
  static FilialeModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? <String, dynamic>{};
    final m = Map<String, dynamic>.from(data);
    m['id'] ??= int.tryParse(d.id);
    return FilialeModel.fromMap(m);
  }

  static Map<String, dynamic> _toFirestore(
    FilialeModel f, {
    required int id,
    bool isUpdate = false,
  }) {
    final m = Map<String, dynamic>.from(f.toMap());
    m['id'] = id;

    // Normalisation abréviation
    final abrevNorm = _norm(m['abreviation'] as String? ?? '');
    m['abreviation'] = abrevNorm;
    m['abreviation_norm'] = abrevNorm;

    if (isUpdate) {
      m['updated_at'] = FieldValue.serverTimestamp();
    } else {
      m['created_at'] ??= FieldValue.serverTimestamp();
      m['updated_at'] = FieldValue.serverTimestamp();
    }
    return m;
  }

  // ---------- READ ----------
  static Future<List<FilialeModel>> getAll() async {
    try {
      final snap = await _col.get();
      return snap.docs.map(_fromDoc).toList();
    } catch (e, st) {
      debugPrint('FilialeDAO.getAll error: $e\n$st');
      rethrow;
    }
  }

  static Future<FilialeModel?> getById(int id) async {
    try {
      final doc = await _col.doc(id.toString()).get();
      if (!doc.exists) return null;
      return _fromDoc(doc);
    } catch (e, st) {
      debugPrint('FilialeDAO.getById($id) error: $e\n$st');
      return null;
    }
  }

  // ---------- WRITE ----------
  /// Insert (id auto = timestamp) avec contrôle d’unicité — retourne l'ID
  static Future<int> insert(FilialeModel f) async {
    try {
      // vérif unicité sur la valeur fournie
      if (await abreviationExists(f.abreviation)) {
        throw StateError('ABREV_DUP');
      }

      final id = f.id ?? _genId();
      final data = _toFirestore(f, id: id, isUpdate: false);
      await _col.doc(id.toString()).set(data);
      return id; // ✅ cohérent avec les autres DAO
    } catch (e, st) {
      debugPrint('FilialeDAO.insert error: $e\n$st');
      rethrow;
    }
  }

  /// Update (nécessite id) avec contrôle si l’abréviation change — retourne 1
  static Future<int> update(FilialeModel f) async {
    if (f.id == null) throw ArgumentError('update() nécessite un id');
    try {
      final docRef = _col.doc(f.id.toString());
      final snap = await docRef.get();
      if (!snap.exists) throw StateError('Filiale introuvable');

      final current = Map<String, dynamic>.from(snap.data()!);
      final newNorm = _norm(f.abreviation);
      final oldNorm =
          (current['abreviation_norm'] as String?) ??
          _norm(current['abreviation'] ?? '');

      if (newNorm != oldNorm &&
          await abreviationExists(newNorm, excludeId: f.id)) {
        throw StateError('ABREV_DUP');
      }

      final data = _toFirestore(f, id: f.id!, isUpdate: true);
      await docRef.update(data);
      return 1;
    } catch (e, st) {
      debugPrint('FilialeDAO.update error: $e\n$st');
      rethrow;
    }
  }

  static Future<int> delete(int id) async {
    try {
      await _col.doc(id.toString()).delete();
      return 1;
    } catch (e, st) {
      debugPrint('FilialeDAO.delete($id) error: $e\n$st');
      rethrow;
    }
  }

  static Stream<List<FilialeModel>> watchAll() {
    try {
      return _col.snapshots().map((q) => q.docs.map(_fromDoc).toList());
    } catch (e, st) {
      debugPrint('FilialeDAO.watchAll error: $e\n$st');
      rethrow;
    }
  }
}
