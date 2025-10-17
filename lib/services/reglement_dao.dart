import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reglement.dart';

const String _kReglementsCol = 'reglements';

class ReglementDAO {
  static final _col = FirebaseFirestore.instance.collection(_kReglementsCol);
  static int _genId() => DateTime.now().millisecondsSinceEpoch;

  static Future<List<Reglement>> getAll() async {
    try {
      final snap = await _col.get();
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] ??= int.tryParse(d.id);
        return Reglement.fromMap(data);
      }).toList();
    } catch (e, st) {
      debugPrint('ReglementDAO.getAll error: $e\n$st');
      rethrow;
    }
  }

  static Future<List<Reglement>> getByCommande(int commandeId) async {
    try {
      final snap = await _col.where('commande_id', isEqualTo: commandeId).get();
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] ??= int.tryParse(d.id);
        return Reglement.fromMap(data);
      }).toList();
    } catch (e, st) {
      debugPrint('ReglementDAO.getByCommande($commandeId) error: $e\n$st');
      rethrow;
    }
  }

  static Future<Reglement?> getById(int id) async {
    try {
      final doc = await _col.doc(id.toString()).get();
      if (!doc.exists) return null;
      final data = Map<String, dynamic>.from(doc.data()!);
      data['id'] ??= int.tryParse(doc.id);
      return Reglement.fromMap(data);
    } catch (e, st) {
      debugPrint('ReglementDAO.getById($id) error: $e\n$st');
      return null;
    }
  }

  static Future<int> insert(Reglement r) async {
    try {
      final id = r.id ?? _genId();
      final data = Map<String, dynamic>.from(r.toMap())..['id'] = id;
      await _col.doc(id.toString()).set(data);
      return 1;
    } catch (e, st) {
      debugPrint('ReglementDAO.insert error: $e\n$st');
      rethrow;
    }
  }

  static Future<int> update(Reglement r) async {
    if (r.id == null) throw ArgumentError('update() nécessite un id');
    try {
      await _col.doc(r.id.toString()).update(r.toMap());
      return 1;
    } catch (e, st) {
      debugPrint('ReglementDAO.update error: $e\n$st');
      rethrow;
    }
  }

  static Future<int> delete(int id) async {
    try {
      await _col.doc(id.toString()).delete();
      return 1;
    } catch (e, st) {
      debugPrint('ReglementDAO.delete($id) error: $e\n$st');
      rethrow;
    }
  }

  static Stream<List<Reglement>> watchAll() {
    try {
      return _col.snapshots().map(
        (q) => q.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          data['id'] ??= int.tryParse(d.id);
          return Reglement.fromMap(data);
        }).toList(),
      );
    } catch (e, st) {
      debugPrint('ReglementDAO.watchAll error: $e\n$st');
      rethrow;
    }
  }

  static Stream<List<Reglement>> watchByCommande(int commandeId) {
    try {
      return _col
          .where('commande_id', isEqualTo: commandeId)
          .snapshots()
          .map(
            (q) => q.docs.map((d) {
              final data = Map<String, dynamic>.from(d.data());
              data['id'] ??= int.tryParse(d.id);
              return Reglement.fromMap(data);
            }).toList(),
          );
    } catch (e, st) {
      debugPrint('ReglementDAO.watchByCommande error: $e\n$st');
      rethrow;
    }
  }
}
