import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/entretien.dart';

const String _kEntCol = 'entretiens';

class EntretienDAO {
  static final _col = FirebaseFirestore.instance.collection(_kEntCol);
  static int _genId() => DateTime.now().millisecondsSinceEpoch;

  static Future<List<Entretien>> getByVehicule(int vehiculeId) async {
    try {
      final snap = await _col.where('vehicule_id', isEqualTo: vehiculeId).get();
      return snap.docs.map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['id'] ??= int.tryParse(d.id);
        return Entretien.fromMap(m);
      }).toList();
    } catch (e, st) {
      debugPrint('EntretienDAO.getByVehicule($vehiculeId) error: $e\n$st');
      rethrow;
    }
  }

  static Future<int> insert(Entretien e) async {
    try {
      final id = e.id ?? _genId();
      final data = Map<String, dynamic>.from(e.toMap())..['id'] = id;
      await _col.doc(id.toString()).set(data);
      return 1;
    } catch (e, st) {
      debugPrint('EntretienDAO.insert error: $e\n$st');
      rethrow;
    }
  }

  static Future<int> update(Entretien e) async {
    if (e.id == null) throw ArgumentError('update() nécessite un id');
    try {
      await _col.doc(e.id.toString()).update(e.toMap());
      return 1;
    } catch (e, st) {
      debugPrint('EntretienDAO.update error: $e\n$st');
      rethrow;
    }
  }

  static Future<int> delete(int id) async {
    try {
      await _col.doc(id.toString()).delete();
      return 1;
    } catch (e, st) {
      debugPrint('EntretienDAO.delete($id) error: $e\n$st');
      rethrow;
    }
  }

  static Stream<List<Entretien>> watchByVehicule(int vehiculeId) {
    try {
      return _col
          .where('vehicule_id', isEqualTo: vehiculeId)
          .snapshots()
          .map((q) => q.docs.map((d) => Entretien.fromMap(d.data())).toList());
    } catch (e, st) {
      debugPrint('EntretienDAO.watchByVehicule error: $e\n$st');
      return Stream.error(e);
    }
  }
}
