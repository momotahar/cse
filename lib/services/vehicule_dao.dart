// lib/services/vehicule_dao.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vehicule.dart';

const String _kVehiculesCol = 'vehicules';

class VehiculeDAO {
  static final _col = FirebaseFirestore.instance.collection(_kVehiculesCol);

  static int _genId() => DateTime.now().millisecondsSinceEpoch;

  // ───────────────── READ ─────────────────
  static Future<List<Vehicule>> getAll() async {
    try {
      final snap = await _col.orderBy('immatriculation').get();
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] ??= int.tryParse(d.id);
        return Vehicule.fromMap(data);
      }).toList();
    } catch (e, st) {
      debugPrint('VehiculeDAO.getAll error: $e\n$st');
      rethrow;
    }
  }

  static Future<Vehicule?> getById(int id) async {
    try {
      final d = await _col.doc(id.toString()).get();
      if (!d.exists) return null;
      final data = Map<String, dynamic>.from(d.data()!);
      data['id'] ??= int.tryParse(d.id);
      return Vehicule.fromMap(data);
    } catch (e, st) {
      debugPrint('VehiculeDAO.getById($id) error: $e\n$st');
      rethrow; // on laisse l’UI gérer l’erreur
    }
  }

  // ───────────────── WRITE ─────────────────
  static Future<int> insert(Vehicule v) async {
    try {
      final id = v.id ?? _genId();
      final data = Map<String, dynamic>.from(v.toMap())..['id'] = id;
      await _col.doc(id.toString()).set(data);
      return 1;
    } catch (e, st) {
      debugPrint('VehiculeDAO.insert error: $e\n$st');
      rethrow;
    }
  }

  static Future<int> update(Vehicule v) async {
    if (v.id == null) {
      throw ArgumentError('update() nécessite un id');
    }
    try {
      await _col.doc(v.id.toString()).update(v.toMap());
      return 1;
    } catch (e, st) {
      debugPrint('VehiculeDAO.update error: $e\n$st');
      rethrow;
    }
  }

  static Future<int> delete(int id) async {
    try {
      await _col.doc(id.toString()).delete();
      return 1;
    } catch (e, st) {
      debugPrint('VehiculeDAO.delete($id) error: $e\n$st');
      rethrow;
    }
  }

  // ──────────────── STREAM ────────────────
  static Stream<List<Vehicule>> watchAll() {
    try {
      return _col
          .orderBy('immatriculation')
          .snapshots()
          .map(
            (q) => q.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] ??= int.tryParse(d.id);
              return Vehicule.fromMap(data);
            }).toList(),
          );
    } catch (e, st) {
      debugPrint('VehiculeDAO.watchAll error: $e\n$st');
      rethrow;
    }
  }
}
