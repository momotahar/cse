// lib/services/reglement_dao.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reglement.dart';

const String _kReglementsCol = 'reglements';

class ReglementDAO {
  static final _col = FirebaseFirestore.instance.collection(_kReglementsCol);
  static int _genId() => DateTime.now().millisecondsSinceEpoch;

  // --- Mapping helpers (cohérent avec BilletDAO)
  static Reglement _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? <String, dynamic>{};
    final m = Map<String, dynamic>.from(data);
    m['id'] ??= int.tryParse(d.id);
    return Reglement.fromMap(m);
  }

  static Map<String, dynamic> _toFirestore(
    Reglement r, {
    required int id,
    bool isUpdate = false,
  }) {
    final m = Map<String, dynamic>.from(r.toMap());
    m['id'] = id;
    if (isUpdate) {
      m['updated_at'] = FieldValue.serverTimestamp();
    } else {
      m['created_at'] ??= FieldValue.serverTimestamp();
    }
    return m;
  }

  /// Tous les règlements (tri récent -> ancien si created_at présent)
  static Future<List<Reglement>> getAll() async {
    try {
      final snap = await _col.get();
      final list = snap.docs.map(_fromDoc).toList();
      // tri défensif : par created_at desc si dispo, sinon par id desc
      list.sort((a, b) {
        final ad = (a.toMap()['created_at'] as Timestamp?);
        final bd = (b.toMap()['created_at'] as Timestamp?);
        if (ad != null && bd != null) return bd.compareTo(ad);
        return (b.id ?? 0).compareTo(a.id ?? 0);
      });
      return list;
    } catch (e, st) {
      debugPrint('ReglementDAO.getAll error: $e\n$st');
      rethrow;
    }
  }

  /// Par commande
  static Future<List<Reglement>> getByCommande(int commandeId) async {
    try {
      final snap = await _col.where('commande_id', isEqualTo: commandeId).get();
      final list = snap.docs.map(_fromDoc).toList();
      list.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
      return list;
    } catch (e, st) {
      debugPrint('ReglementDAO.getByCommande($commandeId) error: $e\n$st');
      rethrow;
    }
  }

  /// Un règlement
  static Future<Reglement?> getById(int id) async {
    try {
      final doc = await _col.doc(id.toString()).get();
      if (!doc.exists) return null;
      return _fromDoc(doc);
    } catch (e, st) {
      debugPrint('ReglementDAO.getById($id) error: $e\n$st');
      return null;
    }
  }

  /// Insert — retourne l’ID généré (≠ 1)
  static Future<int> insert(Reglement r) async {
    try {
      final id = r.id ?? _genId();
      final data = _toFirestore(r, id: id, isUpdate: false);
      await _col.doc(id.toString()).set(data);
      return id; // ✅ cohérent avec BilletDAO
    } catch (e, st) {
      debugPrint('ReglementDAO.insert error: $e\n$st');
      rethrow;
    }
  }

  /// Update — retourne 1 si OK
  static Future<int> update(Reglement r) async {
    if (r.id == null) throw ArgumentError('update() nécessite un id');
    try {
      final data = _toFirestore(r, id: r.id!, isUpdate: true);
      await _col.doc(r.id.toString()).update(data);
      return 1;
    } catch (e, st) {
      debugPrint('ReglementDAO.update error: $e\n$st');
      rethrow;
    }
  }

  /// Delete — retourne 1 si OK
  static Future<int> delete(int id) async {
    try {
      await _col.doc(id.toString()).delete();
      return 1;
    } catch (e, st) {
      debugPrint('ReglementDAO.delete($id) error: $e\n$st');
      rethrow;
    }
  }

  /// Flux temps réel — tous
  static Stream<List<Reglement>> watchAll() {
    try {
      return _col.snapshots().map((q) {
        final list = q.docs.map(_fromDoc).toList()
          ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
        return list;
      });
    } catch (e, st) {
      debugPrint('ReglementDAO.watchAll error: $e\n$st');
      rethrow;
    }
  }

  /// Flux temps réel — par commande
  static Stream<List<Reglement>> watchByCommande(int commandeId) {
    try {
      return _col.where('commande_id', isEqualTo: commandeId).snapshots().map((
        q,
      ) {
        final list = q.docs.map(_fromDoc).toList()
          ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
        return list;
      });
    } catch (e, st) {
      debugPrint('ReglementDAO.watchByCommande error: $e\n$st');
      rethrow;
    }
  }
}
