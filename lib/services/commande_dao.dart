import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/commande.dart';

const String _kCommandesCol = 'commandes';

class CommandeDAO {
  static final _col = FirebaseFirestore.instance.collection(_kCommandesCol);
  static int _genId() => DateTime.now().millisecondsSinceEpoch;

  static Future<List<Commande>> getAll() async {
    try {
      final snap = await _col.get();
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] ??= int.tryParse(d.id);
        return Commande.fromMap(data);
      }).toList();
    } catch (e, st) {
      debugPrint('CommandeDAO.getAll error: $e\n$st');
      rethrow;
    }
  }

  static Future<List<Commande>> getByMonthYear(int month, int year) async {
    try {
      // On récupère tout, puis filtre local (simples règles Firestore côté client).
      final all = await getAll();
      return all
          .where((c) => c.date.month == month && c.date.year == year)
          .toList();
    } catch (e, st) {
      debugPrint('CommandeDAO.getByMonthYear($month/$year) error: $e\n$st');
      rethrow;
    }
  }

  static Future<Commande?> getById(int id) async {
    try {
      final doc = await _col.doc(id.toString()).get();
      if (!doc.exists) return null;
      final data = Map<String, dynamic>.from(doc.data()!);
      data['id'] ??= int.tryParse(doc.id);
      return Commande.fromMap(data);
    } catch (e, st) {
      debugPrint('CommandeDAO.getById($id) error: $e\n$st');
      return null;
    }
  }

  static Future<int> insert(Commande c) async {
    try {
      final id = c.id ?? _genId();
      final data = Map<String, dynamic>.from(c.toMap())..['id'] = id;
      await _col.doc(id.toString()).set(data);
      return 1;
    } catch (e, st) {
      debugPrint('CommandeDAO.insert error: $e\n$st');
      rethrow;
    }
  }

  static Future<int> update(Commande c) async {
    if (c.id == null) throw ArgumentError('update() nécessite un id');
    try {
      await _col.doc(c.id.toString()).update(c.toMap());
      return 1;
    } catch (e, st) {
      debugPrint('CommandeDAO.update error: $e\n$st');
      rethrow;
    }
  }

  static Future<int> delete(int id) async {
    try {
      await _col.doc(id.toString()).delete();
      return 1;
    } catch (e, st) {
      debugPrint('CommandeDAO.delete($id) error: $e\n$st');
      rethrow;
    }
  }

  static Stream<List<Commande>> watchAll() {
    try {
      return _col.snapshots().map(
        (q) => q.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          data['id'] ??= int.tryParse(d.id);
          return Commande.fromMap(data);
        }).toList(),
      );
    } catch (e, st) {
      debugPrint('CommandeDAO.watchAll error: $e\n$st');
      rethrow;
    }
  }
}
