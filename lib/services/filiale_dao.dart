import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    // s'il y a un doc mais que c'est le même id, on considère que ce n'est pas un doublon
    final doc = q.docs.first;
    final data = doc.data();
    final existingId = (data['id'] is int)
        ? data['id'] as int
        : int.tryParse(doc.id);
    return existingId != excludeId;
  }

  /// Récupère toutes les filiales
  static Future<List<FilialeModel>> getAll() async {
    try {
      final snap = await _col.get();
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] ??= int.tryParse(d.id);
        return FilialeModel.fromMap(data);
      }).toList();
    } catch (e, st) {
      debugPrint('FilialeDAO.getAll error: $e\n$st');
      rethrow;
    }
  }

  static Future<FilialeModel?> getById(int id) async {
    try {
      final doc = await _col.doc(id.toString()).get();
      if (!doc.exists) return null;
      final data = Map<String, dynamic>.from(doc.data()!);
      data['id'] ??= int.tryParse(doc.id);
      return FilialeModel.fromMap(data);
    } catch (e, st) {
      debugPrint('FilialeDAO.getById($id) error: $e\n$st');
      return null;
    }
  }

  /// Insert (id auto = timestamp) avec contrôle d’unicité
  static Future<int> insert(FilialeModel f) async {
    try {
      final norm = _norm(f.abreviation);
      // vérif unicité
      if (await abreviationExists(norm)) {
        throw StateError("ABREV_DUP"); // code simple à intercepter côté UI
      }

      final id = f.id ?? _genId();
      final data = Map<String, dynamic>.from(f.toMap())
        ..['id'] = id
        ..['abreviation'] = norm
        ..['abreviation_norm'] = norm; // champ d’index

      await _col.doc(id.toString()).set(data);
      return 1;
    } catch (e, st) {
      debugPrint('FilialeDAO.insert error: $e\n$st');
      rethrow;
    }
  }

  /// Update (nécessite id) avec contrôle si l’abréviation change
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

      // si l’abréviation a changé, vérifie l’unicité
      if (newNorm != oldNorm &&
          await abreviationExists(newNorm, excludeId: f.id)) {
        throw StateError("ABREV_DUP");
      }

      final data = Map<String, dynamic>.from(f.toMap())
        ..['abreviation'] = newNorm
        ..['abreviation_norm'] = newNorm;

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
      return _col.snapshots().map(
        (q) => q.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          data['id'] ??= int.tryParse(d.id);
          return FilialeModel.fromMap(data);
        }).toList(),
      );
    } catch (e, st) {
      debugPrint('FilialeDAO.watchAll error: $e\n$st');
      rethrow;
    }
  }
}
