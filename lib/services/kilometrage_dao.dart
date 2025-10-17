import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/kilometrage.dart';

const String _kKiloCol = 'kilometrages';

class KilometrageDAO {
  static final _col = FirebaseFirestore.instance.collection(_kKiloCol);
  static int _genId() => DateTime.now().millisecondsSinceEpoch;

  // ─────────────────── READ ───────────────────
  static Future<List<Kilometrage>> getAll() async {
    try {
      final snap = await _col.get();
      return snap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['id'] ??= int.tryParse(d.id);
        return Kilometrage.fromMap(m);
      }).toList();
    } catch (e, st) {
      debugPrint('KilometrageDAO.getAll error: $e\n$st');
      rethrow;
    }
  }

  static Future<List<Kilometrage>> getByAnnee(int annee) async {
    try {
      final q = await _col.where('annee', isEqualTo: annee).get();
      return q.docs.map((d) => Kilometrage.fromMap(d.data())).toList();
    } catch (e, st) {
      debugPrint('KilometrageDAO.getByAnnee($annee) error: $e\n$st');
      rethrow;
    }
  }

  static Future<List<Kilometrage>> getByVehicule(
    int vehiculeId, {
    int? annee,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _col.where(
        'vehicule_id',
        isEqualTo: vehiculeId,
      );
      if (annee != null) q = q.where('annee', isEqualTo: annee);
      final snap = await q.get();
      return snap.docs.map((d) => Kilometrage.fromMap(d.data())).toList();
    } catch (e, st) {
      debugPrint(
        'KilometrageDAO.getByVehicule($vehiculeId,$annee) error: $e\n$st',
      );
      rethrow;
    }
  }

  static Future<Kilometrage?> getByVehiculeMoisAnnee(
    int vehiculeId,
    int mois,
    int annee,
  ) async {
    try {
      final q = await _col
          .where('vehicule_id', isEqualTo: vehiculeId)
          .where('mois', isEqualTo: mois)
          .where('annee', isEqualTo: annee)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return null;
      final m = Map<String, dynamic>.from(q.docs.first.data());
      m['id'] ??= int.tryParse(q.docs.first.id);
      return Kilometrage.fromMap(m);
    } catch (e, st) {
      debugPrint('KilometrageDAO.getByVehiculeMoisAnnee error: $e\n$st');
      rethrow;
    }
  }

  // ─────────────────── WRITE ───────────────────
  static Future<int> insert(Kilometrage k) async {
    try {
      final id = k.id ?? _genId();
      final data = Map<String, dynamic>.from(k.toMap())..['id'] = id;
      await _col.doc(id.toString()).set(data);
      return 1;
    } catch (e, st) {
      debugPrint('KilometrageDAO.insert error: $e\n$st');
      rethrow;
    }
  }

  static Future<int> update(Kilometrage k) async {
    if (k.id == null) throw ArgumentError('update() nécessite un id');
    try {
      await _col.doc(k.id.toString()).update(k.toMap());
      return 1;
    } catch (e, st) {
      debugPrint('KilometrageDAO.update error: $e\n$st');
      rethrow;
    }
  }

  static Future<int> delete(int id) async {
    try {
      await _col.doc(id.toString()).delete();
      return 1;
    } catch (e, st) {
      debugPrint('KilometrageDAO.delete($id) error: $e\n$st');
      rethrow;
    }
  }

  /// Upsert par (vehiculeId, mois, annee) — évite les doublons mensuels.
  static Future<int> upsertByKey({
    required int vehiculeId,
    required int mois,
    required int annee,
    required int kilometrage,
  }) async {
    try {
      final existing = await getByVehiculeMoisAnnee(vehiculeId, mois, annee);
      if (existing == null) {
        return await insert(
          Kilometrage(
            vehiculeId: vehiculeId,
            mois: mois,
            annee: annee,
            kilometrage: kilometrage,
          ),
        );
      } else {
        return await update(existing.copyWith(kilometrage: kilometrage));
      }
    } catch (e, st) {
      debugPrint('KilometrageDAO.upsertByKey error: $e\n$st');
      rethrow;
    }
  }

  // ─────────────── Streams (optionnel) ───────────────
  static Stream<List<Kilometrage>> watchByAnnee(int annee) {
    try {
      return _col
          .where('annee', isEqualTo: annee)
          .snapshots()
          .map(
            (q) => q.docs.map((d) => Kilometrage.fromMap(d.data())).toList(),
          );
    } catch (e, st) {
      debugPrint('KilometrageDAO.watchByAnnee error: $e\n$st');
      return Stream.error(e);
    }
  }

  static Stream<List<Kilometrage>> watchByVehicule(
    int vehiculeId, {
    int? annee,
  }) {
    try {
      Query<Map<String, dynamic>> q = _col.where(
        'vehicule_id',
        isEqualTo: vehiculeId,
      );
      if (annee != null) q = q.where('annee', isEqualTo: annee);
      return q.snapshots().map(
        (s) => s.docs.map((d) => Kilometrage.fromMap(d.data())).toList(),
      );
    } catch (e, st) {
      debugPrint('KilometrageDAO.watchByVehicule error: $e\n$st');
      return Stream.error(e);
    }
  }
}
